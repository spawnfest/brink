defmodule BrinkDemo.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {BrinkDemo.Ticker, 3_000}
    ]

    opts = [strategy: :one_for_one, name: BrinkDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
