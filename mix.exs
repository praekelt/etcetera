defmodule Etcetera.MixProject do
  use Mix.Project

  def project do
    [
      app: :etcetera,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      name: "Etcetera",
      source_url: "https://github.com/praekelt/etcetera"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      env: [],
    ]
  end

  defp description do
    "A simple client for working with an Etcd store in Elixir."
  end

  defp package do
    [
      name: "etcetera",
      files: ~w(config lib test .formatter.exs mix.exs README* CHANGELOG* LICENSE*),
      licenses: ["BSD-3-Clause"],
      links: %{"GitHub" => "https://github.com/praekelt/etcetera"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 1.8"},
      {:jason, "~> 1.2"},
      {:ex_doc, "~> 0.23.0", only: :dev, runtime: false}
    ]
  end
end
