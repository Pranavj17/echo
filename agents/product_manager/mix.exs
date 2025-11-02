defmodule ProductManager.MixProject do
  use Mix.Project

  def project do
    [
      app: :product_manager,
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
      mod: {ProductManager.Application, []}
    ]
  end

  defp deps do
    [
      {:echo_shared, path: "../../shared"}
    ]
  end

  defp escript do
    [
      main_module: ProductManager.CLI,
      name: "product_manager"
    ]
  end
end
