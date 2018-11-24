defmodule BrinkDemo.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    redis_uri = "redis://redis"
    stream = "brink"

    children = [
      {BrinkDemo.Ticker, 3_000},
      {BrinkDemo.Tailer, interval: 3_000, redis_uri: redis_uri, stream: stream},
      {BrinkDemo.Producer, redis_uri: redis_uri, stream: stream}
    ]

    opts = [strategy: :one_for_one, name: BrinkDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
