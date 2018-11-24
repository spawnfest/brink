defmodule BrinkDemo.Tailer do
  use GenServer

  def start_link(options \\ []) do
    interval = Keyword.fetch!(options, :interval)
    {:ok, client} = Redix.start_link(Keyword.fetch!(options, :redis_uri))
    stream = Keyword.fetch!(options, :stream)
    GenServer.start_link(__MODULE__, {interval, client, stream})
  end

  def init(state) do
    {:ok, state, 1000}
  end

  def handle_info(:timeout, {interval, client, stream} = state) do
    Redix.command!(client, ["XREVRANGE", stream, "+", "-", "COUNT", "10"])
    |> IO.inspect()
    {:noreply, state, interval}
  end
end
