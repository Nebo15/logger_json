defmodule LoggerJSON.Mixfile do
  use Mix.Project

  @source_url "https://github.com/Nebo15/logger_json"
  @version "6.0.1"

  def project do
    [
      app: :logger_json,
      version: @version,
      elixir: "~> 1.16 or ~> 1.15.1",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [] ++ Mix.compilers(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.travis": :test, "coveralls.html": :test],
      dialyzer: [
        plt_add_apps: [:plug]
      ]
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
      {:jason, "~> 1.4"},
      {:plug, "~> 1.15", optional: true},
      {:ecto, "~> 3.11", optional: true},
      {:telemetry, "~> 1.0", optional: true},
      {:stream_data, "~> 1.0", only: [:dev, :test]},
      {:castore, "~> 1.0", only: [:dev, :test]},
      {:excoveralls, ">= 0.15.0", only: [:dev, :test]},
      {:junit_formatter, "~> 3.3", only: [:test]},
      {:ex_doc, ">= 0.15.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.0", only: [:dev], runtime: false}
    ]
  end

  defp package do
    [
      description: """
      This package includes a set of :logger formatters designed to output logs in JSON format.
      It is compatible with a variety of log management systems that support JSON,
      including Google Cloud Logging and Error Reporting, Datadog, ElasticSearch, LogStash, FileBeat, and Kibana.
      """,
      contributors: ["Andrew Dryga"],
      maintainers: ["Andrew Dryga"],
      licenses: ["MIT"],
      files: ~w(lib LICENSE.md mix.exs README.md),
      links: %{
        Changelog: "https://github.com/Nebo15/logger_json/releases",
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
      source_ref: @version,
      formatters: ["html"]
    ]
  end
end
