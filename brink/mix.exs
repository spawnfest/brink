defmodule Brink.Mixfile do
  use Mix.Project

  def project do
    [
      app: :brink,
      version: "0.1.0",
      elixir: "~> 1.5",
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:gen_stage, "~> 0.14"}
    ]
  end
end
