defmodule Brink.Consumer do
  use GenStage

  @moduledoc """
  Brink.Consumer is a GenStage producer that consumes events from a Redis
  Stream. It can be used, with one or more processes, as a source for
  Flow.from_stages/Flow.from_specs . A Brick.Consumer process is a single
  consumer part of a consumer group. It is important to have unique names
  for consumers and it's important to restart a consumer after a crash with
  the same name so that unprocessed messages will be retries.
  """

  # Known debt:
  # - The code deals with pending messages from previous runs, but the code
  #   doesn't really allow for pending messages to be created because it's
  #   using NOACK. We should find a way to track processing of messages to
  #   XACK them properly only once they've been processed.
  # - The code should support multiple streams being tracked individually.

  def start_link(options \\ []) do
    GenStage.start_link(__MODULE__, options, name: Keyword.get(options, :name, __MODULE__))
  end

  def init(options \\ []) do
    redis_client =
      case Keyword.get(options, :redis_client) do
        nil ->
          redis_uri = Keyword.get(options, :redis_uri, "redis://localhost")
          {:ok, client} = Redix.start_link(redis_uri)
          client

        client ->
          client
      end

    mode = Keyword.get(options, :mode, :single)

    with {:ok, stream} <- Keyword.fetch(options, :stream),
         {:ok, mode_state} <- parse_mode_options(mode, options),
           poll_interval <- Keyword.get(options, :poll_interval, 100) do
      state = %{
        client: redis_client,
        stream: stream,
        mode: mode,
        demand: 0,
        poll_interval: poll_interval
      }

      producer_options =
        case Keyword.fetch(options, :dispatcher) do
          {:ok, dispatcher} ->
            [dispatcher: dispatcher]

          _ ->
            []
        end

      {:producer, Map.merge(state, mode_state), producer_options}
    else
      _ -> {:stop, "invalid arguments"}
    end
  end

  defp parse_mode_options(:single, options) do
    with {:ok, start_id} <- Keyword.fetch(options, :start_id) do
      {:ok,
       %{
         next_id: start_id,
         initial_block_timeout: Keyword.get(options, :initial_block_timeout, 1_000)
       }}
    else
      _ -> {:error, :badarg}
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
