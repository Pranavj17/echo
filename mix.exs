defmodule Echo.MixProject do
  use Mix.Project

  def project do
    [
      apps: [
        :echo_shared,
        :ceo,
        :cto,
        :chro,
        :operations_head,
        :product_manager,
        :senior_architect,
        :senior_developer,
        :test_lead,
        :uiux_engineer,
        :echo_monitor
      ],
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Dependencies listed here are available only for this project
  # and cannot be accessed from applications inside the apps/ folder.
  defp deps do
    []
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # Aliases listed here are available only for this project
  # and cannot be accessed from applications inside the apps/ folder.
  defp aliases do
    agent_apps = [
      "ceo",
      "cto",
      "chro",
      "operations_head",
      "product_manager",
      "senior_architect",
      "senior_developer",
      "test_lead",
      "uiux_engineer"
    ]

    [
      # Run tests in all apps
      test: ["cmd mix test"],
      # Compile all apps
      compile: ["cmd mix compile"],
      # Build all agent escripts
      "escript.build": prepare_cmd(agent_apps, "cmd mix escript.build")
    ]
  end

  defp prepare_cmd(apps, command) do
    "do " <>
      Enum.map_join(apps, " ", fn app ->
        "--app #{app} " <> command
      end)
  end
end
