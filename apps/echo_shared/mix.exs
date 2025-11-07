defmodule EchoShared.MixProject do
  use Mix.Project

  def project do
    [
      app: :echo_shared,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "./config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Documentation
      name: "ECHO Shared",
      source_url: "https://github.com/Pranavj17/echo",
      docs: [
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {EchoShared.Application, []}
    ]
  end

  defp deps do
    [
      # Database
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.19"},

      # Redis
      {:redix, "~> 1.5"},

      # JSON
      {:jason, "~> 1.4"},

      # UUID generation
      {:uuid, "~> 1.1"},

      # HTTP client for LLM integration
      {:req, "~> 0.5"},
      {:telemetry, "~> 1.2"},

      # Documentation
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
