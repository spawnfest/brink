defmodule Brink.Mixfile do
  use Mix.Project

  def project do
    [
      app: :brink,
      version: "0.1.1",
      elixir: "~> 1.7",
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      description: "Elixir GenStage front-end for Redis Streams",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/spawnfest/team-brb/"}
    ]
  end

  defp deps do
    [
      {:flow, "~> 0.14", only: [:dev]},
      {:gen_stage, "~> 0.14"},
      {:redix, "~> 0.9.0"}
    ]
  end
end
