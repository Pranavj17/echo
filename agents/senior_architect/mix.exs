defmodule SeniorArchitect.MixProject do
  use Mix.Project

  def project do
    [
      app: :senior_architect,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {SeniorArchitect.Application, []}
    ]
  end

  defp deps do
    [
      {:echo_shared, path: "../../shared"}
    ]
  end

  defp escript do
    [
      main_module: SeniorArchitect.CLI,
      name: "senior_architect"
    ]
  end
end
