defmodule Brink.Producer do
  use GenStage

  @moduledoc """
  Brink.Producer is a GenStage consumer that produces events to a Redis
  Stream. It can be used, with one or more processes, as a sink for
  Flow.into_stages/Flow.into_specs.
  """

  @doc """
  Builds a child specification tuple intended to be used by Flow.into_specs or
  Flow.into_stages.

  ## Options
  * `:name` - the name of the process. Defaults to `Brink.Producer`
  * `:maxlen` - the maximum size of the underlying Redis stream, passed to the
     `MAXLEN` option of the Redis `XADD` command. Defaults to `nil`, for no
     maximum stream length.
  """
  @spec build_spec(String.t(), String.t(), keyword()) :: {atom(), keyword()}
  def build_spec(redis_uri, stream, options \\ []) do
    {__MODULE__, Keyword.merge(options, redis_uri: redis_uri, stream: stream)}
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options \\ []) do
    GenStage.start_link(__MODULE__, options, name: Keyword.get(options, :name, __MODULE__))
  end

  def init(options \\ []) do
    {:ok, redis_client} = Redix.start_link(Keyword.fetch!(options, :redis_uri))

    state = %{
      client: redis_client,
      stream: Keyword.fetch!(options, :stream),
      maxlen: Keyword.get(options, :maxlen, nil)
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

    List.flatten(["XADD", stream, maxlen_args, "*", dict_args])
  end
end
