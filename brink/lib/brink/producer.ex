defmodule Brink.Producer do
  use GenStage

  @moduledoc """
  Brink.Producer is a GenStage consumer that produces events to a Redis
  Stream. It can be used, with one or more processes, as a sink for
  Flow.into_stages/Flow.into_specs .
  """

  # Options:
  # - :name, defaults to __MODULE__
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options \\ []) do
    GenStage.start_link(__MODULE__, options, name: Keyword.get(options, :name, __MODULE__))
  end

  # Required:
  # - :redis_uri
  # - :stream
  # - :maxlen
  def init(options \\ []) do
      {:ok, redis_client} = Redix.start_link(Keyword.fetch!(options, :redis_uri))
      state = %{
        client: redis_client,
        stream: Keyword.fetch!(options, :stream),
        maxlen: Keyword.fetch!(options, :maxlen)
      }

      {:consumer, state}
  end

  def terminate(_reason, state) do
    Redix.stop(state[:client])
  end

  # ignoring incoming messages to clear mailbox
  def handle_info(_, state), do: {:noreply, [], state}

  def handle_events(events, _from, state) do
    commands = Enum.map(events, &build_xadd(state.stream, &1, state.maxlen))
    Redix.noreply_pipeline!(state.client, commands)
    {:noreply, [], state}
  end

  defp build_xadd(stream, dict, maxlen) when is_map(dict) do
    build_xadd(stream, Map.to_list(dict), maxlen)
  end

  defp build_xadd(stream, dict, maxlen) when is_list(dict) do
    dict_args =
      dict
      |> Enum.flat_map(fn {k, v} -> [k, v] end)
      |> Enum.map(&to_string/1)

    maxlen_args =
      if maxlen do
        ["MAXLEN", "~", to_string(maxlen)]
      else
        []
      end

    ["XADD", stream] ++ maxlen_args ++ ["*"] ++ dict_args
  end
end
