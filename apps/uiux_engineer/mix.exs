defmodule UiuxEngineer.MixProject do
  use Mix.Project

  def project do
    [
      app: :uiux_engineer,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "./config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {UiuxEngineer.Application, []}
    ]
  end

  defp deps do
    [
      {:echo_shared, in_umbrella: true}
    ]
  end

  defp escript do
    [
      main_module: UiuxEngineer.CLI,
      name: "uiux_engineer"
    ]
  end
end
