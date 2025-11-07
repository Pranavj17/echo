import Config

# Configure Ecto repository
# NOTE: Database connection details are in runtime.exs for production flexibility
# Only static, compile-time configuration here
config :echo_shared, EchoShared.Repo,
  pool_size: 1  # Each agent uses only 1 connection

# Configure Ecto
config :echo_shared, ecto_repos: [EchoShared.Repo]

# Configure logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :agent_role]

# Configure LLM integration (Ollama) - defaults in runtime.exs
config :echo_shared,
  llm_enabled: true  # Can be overridden in runtime.exs

# Configure agent-specific models (can be overridden by environment variables)
# e.g., CEO_MODEL=qwen2.5:14b
config :echo_shared, :agent_models, %{
  ceo: "qwen2.5:14b",                    # Strategic reasoning
  cto: "deepseek-coder:33b",             # Technical architecture
  chro: "llama3.1:8b",                   # People & communication
  operations_head: "mistral:7b",         # Operations & efficiency
  product_manager: "llama3.1:8b",        # Product strategy
  senior_architect: "deepseek-coder:33b", # System design
  uiux_engineer: "llama3.2-vision:11b",  # Design & visual
  senior_developer: "deepseek-coder:6.7b", # Code implementation
  test_lead: "codellama:13b"             # Test generation
}

# Import environment specific config
import_config "#{config_env()}.exs"
