defmodule Brink.Producer do
  use GenStage

  @moduledoc """
  Brink.Producer is a GenStage consumer that produces events to a Redis
  Stream. It can be used, with one or more processes, as a sink for
  Flow.into_stages/Flow.into_specs .
  """

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

    with {:ok, stream} <- Keyword.fetch(options, :stream),
         maxlen <- Keyword.get(options, :maxlen) do
      state = %{
        client: redis_client,
        stream: stream,
        maxlen: maxlen
      }

      {:consumer, state}
    else
      _ -> {:stop, "Missing arguments"}
    end
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
