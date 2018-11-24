defmodule BrinkDemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :brink_demo,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {BrinkDemo.Application, []}
    ]
  end

  defp deps do
    [
      {:brink, ">= 0.0.0", path: "../brink"},
      {:distillery, "~> 2.0", runtime: false},
      {:flow, "~> 0.14"}
    ]
  end
end
