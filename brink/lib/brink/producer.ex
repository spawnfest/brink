defmodule Brink.Producer do
  use GenStage

  @moduledoc """
  The Brink.Producer is a GenStage consumer that produces events to a Redis
  Stream. It can be used, with one or more processes, as a sink for
  Flow.into_stages/Flow.into_specs .
  """

  # Known debt:
  # - Redix linked simplistically and not closed

  def init(options) do
    redis_client = Keyword.get(options, :redis_client)

    if not redis_client do
      redis_uri = Keyword.get(options, :redis_uri, "redis://localhost")
      {:ok, redis_client} = Redix.start_link(redis_uri)
    end

    state = %{
      client: redis_client,
      stream: Keyword.get(options, :stream, "brink"),
      maxlen: Keyword.get(options, :maxlen)
    }

    {:consumer, :some_kind_of_state}
  end

  def handle_events(events, _from, state) do
    commands = Enum.map(events, &build_xadd(state.stream, &1, state.maxlen))
    Redix.noreply_pipeline!(state.client, commands)
    {:noreply, [], state}
  end

  defp build_xadd(dict, maxlen) when is_map(dict) do
    build_xadd(Map.to_list(dict), maxlen)
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
