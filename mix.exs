defmodule Veggy.Mixfile do
  use Mix.Project

  def project do
    [app: :veggy,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [applications: [:logger, :timex, :mongodb, :poolboy, :cowboy, :plug],
     mod: {Veggy, []}]
  end

  defp deps do
    [{:cowboy, "~> 1.0"},
     {:plug, "~> 1.1"},
     {:mongodb, "~> 0.1.1"},
     {:poolboy, "~> 1.5.1"},
     {:poison, "~> 2.2.0"},
     {:inflex, "~> 1.7.0"},
     {:timex, "~> 3.0"},
     {:cors_plug, "~> 1.1"}]
  end
end
