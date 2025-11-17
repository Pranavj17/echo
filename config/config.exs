# This file is responsible for configuring the ECHO umbrella project
import Config

# Configure shared library (echo_shared)
# Individual apps will override these as needed

if Mix.env() == :dev do
  config :logger, :console,
    level: :info,
    format: "$time [$level] $metadata$message\n",
    metadata: [:role, :request_id]
end

if Mix.env() == :test do
  config :logger, :console,
    level: :warning
end

if Mix.env() == :prod do
  config :logger, :console,
    level: :info,
    format: "$time [$level] $message\n"
end

# Import environment specific config (if needed)
# This must remain at the bottom of this file
import_config "#{config_env()}.exs"
