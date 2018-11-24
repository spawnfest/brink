defmodule BrinkDemo.Ticker do
  use GenServer
  @version Mix.Project.config[:version]

  def start_link(interval) do
    GenServer.start_link(__MODULE__, interval)
  end

  def init(interval) do
    {:ok, interval, 1000}
  end

  def code_change(_old_vsn, interval, _extra) do
    {:ok, interval}
  end

  def handle_info(:timeout, interval) do
    time = Time.utc_now() |> Time.to_iso8601()
    IO.puts("Clock #{@version}. The time is: #{time}.")
    {:noreply, interval, interval}
  end
end
