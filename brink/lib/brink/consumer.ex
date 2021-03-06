defmodule Brink.Consumer do
  use GenStage

  @moduledoc """
  Brink.Consumer is a GenStage producer that consumes events from a Redis
  Stream. It can be used, with one or more processes, as a source for
  Flow.from_stages/Flow.from_specs . A Brick.Consumer process is a single
  consumer part of a consumer group. It is important to have unique names
  for consumers and it's important to restart a consumer after a crash with
  the same name so that unprocessed messages will be retries.

  It supports two modes:
  1. In `:single` mode the consumer will iterate over a stream's history from
  `:start_id` and will continue as new events are added to the stream. If
  `:start_id` is set to "$" (the default value) then instead it'll wait for the
  next event and then continue processing the stream from that event.
  2. In `:group` mode the consumer will use Redis Streams' consumer groups
  feature to read new events that weren't read by other consumers in the same
  group. Right now all read messages are immediately acknowledged (using NOACK)
  but in an explicit-acknowledgement reading mode, when the consumer starts it
  will first go over unacknowledged events it has previously read before asking
  for new events, to make sure that they are processed.
  """

  @spec build_spec_single_mode(String.t(), String.t(), keyword()) :: {atom(), keyword()}
  def build_spec_single_mode(redis_uri, stream, options \\ []) do
    {
      __MODULE__,
      Keyword.merge(
        options,
        redis_uri: redis_uri,
        stream: stream,
        mode: :single
      )
    }
  end

  @spec build_spec_group_mode(String.t(), String.t(), String.t(), keyword()) ::
          {atom(), keyword()}
  def build_spec_group_mode(redis_uri, stream, group, options \\ []) do
    {
      __MODULE__,
      Keyword.merge(
        options,
        redis_uri: redis_uri,
        stream: stream,
        group: group,
        mode: :group
      )
    }
  end

  # Options
  # - :name, defaults to __MODULE__
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options \\ []) do
    GenStage.start_link(__MODULE__, options, name: Keyword.get(options, :name, __MODULE__))
  end

  # Required:
  # - :redis_uri
  # - :stream
  # Options:
  # - :poll_interval, defaults to 100
  # - :mode, defaults to :single
  def init(options \\ []) do
    mode = Keyword.get(options, :mode, :single)

    with {:ok, mode_state} <- parse_mode_options(mode, options) do
      stream = Keyword.fetch!(options, :stream)
      {:ok, client} = Redix.start_link(Keyword.fetch!(options, :redis_uri))

      state = %{
        client: client,
        stream: stream,
        mode: mode,
        demand: 0,
        poll_interval: Keyword.get(options, :poll_interval, 100)
      }

      if mode == :group do
        {:ok, msg} = create_group(client, stream, Keyword.fetch!(options, :group))
        IO.puts(msg)
      end

      # {:producer, state, producer_options}
      {:producer, Map.merge(state, mode_state), Keyword.take(options, [:dispatcher])}
    else
      _ -> {:stop, "invalid arguments"}
    end
  end

  def terminate(_reason, state) do
    Redix.stop(state[:client])
  end

  defp parse_mode_options(:single, options) do
    with start_id <- Keyword.get(options, :start_id, "$"),
         initial_block_timeout <- Keyword.get(options, :initial_block_timeout, 10_000) do
      {:ok,
       %{
         next_id: start_id,
         initial_block_timeout: initial_block_timeout
       }}
    end
  end

  defp parse_mode_options(:group, options) do
    with {:ok, group} <- Keyword.fetch(options, :group),
         {:ok, consumer} <- Keyword.fetch(options, :consumer) do
      {:ok,
       %{
         group: group,
         consumer: consumer,
         next_id: "0"
       }}
    else
      _ -> {:error, :badarg}
    end
  end

  defp parse_mode_options(_mode, _options), do: {:error, :badarg}

  def handle_info(:read_from_stream, state) do
    read_from_stream(state)
  end

  # ignoring incoming messages to clear mailbox
  def handle_info(_, state), do: {:noreply, [], state}

  def handle_demand(incoming_demand, state) do
    new_state = %{state | demand: state.demand + incoming_demand}

    read_from_stream(new_state)
  end

  defp read_from_stream(%{demand: 0} = state), do: {:noreply, [], state}

  defp read_from_stream(%{stream: stream} = state) do
    read_command = build_xread(state)

    case Redix.command(state.client, read_command) do
      {:ok, [[^stream, [_ | _] = events]]} ->
        next_id = pick_next_id(state, events)

        new_state = %{state | demand: state.demand - length(events), next_id: next_id}

        if new_state.demand > 0 do
          poll_stream(state.poll_interval)
        end

        formatted_events = Enum.map(events, &format_event/1)

        {:noreply, formatted_events, new_state}

      {:ok, _} ->
        poll_stream(state.poll_interval)
        new_state = %{state | next_id: pick_next_id(state, [])}
        {:noreply, [], new_state}

      {:error, err} ->
        {:stop, err, state}
    end
  end

  defp poll_stream(interval) do
    Process.send_after(self(), :read_from_stream, interval)
  end

  defp build_xread(%{mode: :single, next_id: "$"} = state) do
    [
      "XREAD",
      "BLOCK",
      state.initial_block_timeout,
      "COUNT",
      state.demand,
      "STREAMS",
      state.stream,
      "$"
    ]
  end

  defp build_xread(%{mode: :single} = state) do
    [
      "XREAD",
      "COUNT",
      state.demand,
      "STREAMS",
      state.stream,
      state.next_id
    ]
  end

  defp build_xread(%{mode: :group} = state) do
    [
      "XREADGROUP",
      "GROUP",
      state.group,
      state.consumer,
      "COUNT",
      state.demand,
      "NOACK",
      "STREAMS",
      state.stream,
      state.next_id
    ]
  end

  defp create_group(client, stream, group) do
    case Redix.command(client, ["XGROUP", "CREATE", stream, group, "$", "MKSTREAM"]) do
      {:ok, _} ->
        {:ok, "Created consumer group #{group} for #{stream}"}

      {:error, %Redix.Error{message: "BUSYGROUP Consumer Group name already exists"}} ->
        {:ok, "Consumer group #{group} for #{stream} already exists"}

      # Any unforseen error
      error ->
        error
    end
  end

  defp pick_next_id(%{mode: :single, next_id: next_id}, []), do: next_id

  defp pick_next_id(%{mode: :single}, events) do
    events
    |> Enum.map(&List.first/1)
    |> List.last()
  end

  # If no events were found (history scanning or not), there are definitely no pending messages.
  defp pick_next_id(%{mode: :group}, []), do: ">"

  defp pick_next_id(%{mode: :group, next_id: previous_next_id}, events) do
    if previous_next_id == ">" do
      ">"
    else
      events
      |> Enum.map(&List.first/1)
      |> List.last()
    end
  end

  defp format_event([id, dict]) do
    dict =
      dict
      |> Enum.chunk_every(2)
      |> Enum.map(fn [k, v] -> {:"#{k}", v} end)
      |> Map.new()

    {id, dict}
  end
end
