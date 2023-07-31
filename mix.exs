defmodule LoggerJSON.Mixfile do
  use Mix.Project

  @source_url "https://github.com/stordco/logger_json"
  @version "1.0.0"

  def project do
    [
      app: :logger_json,
      name: "Logger JSON",
      description: "JSON console back-end for Elixir Logger",
      version: @version,
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [] ++ Mix.compilers(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.travis": :test, "coveralls.html": :test],
      dialyzer: [plt_add_apps: [:plug, :phoenix]]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:credo, "~> 1.6.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:ecto, "~> 2.1 or ~> 3.0", optional: true},
      {:ex_doc, "~> 0.28.0", only: [:dev, :test], runtime: false},
      {:excoveralls, ">= 0.15.0", only: [:dev, :test]},
      {:jason, "~> 1.0"},
      {:phoenix, ">= 1.5.0", optional: true},
      {:plug, "~> 1.0", optional: true},
      {:stream_data, "~> 0.5", only: [:dev, :test]},
      {:telemetry, "~> 0.4.0 or ~> 1.0", optional: true}
    ]
  end

  defp package do
    [
      description:
        "Console Logger back-end, Plug and Ecto adapter " <>
          "that writes logs in JSON format.",
      contributors: ["Nebo #15", "btkostner"],
      maintainers: ["Nebo #15", "btkostner"],
      organization: "stord",
      licenses: ["MIT"],
      files: ~w(lib LICENSE.md mix.exs README.md),
      links: %{
        Changelog: "https://hexdocs.pm/logger_json/changelog.html",
        GitHub: @source_url
      }
    ]
  end

  defp docs do
    [
      extras: [
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"]
    ]
  end
end
