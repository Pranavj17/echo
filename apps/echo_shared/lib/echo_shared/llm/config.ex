defmodule EchoShared.LLM.Config do
  @moduledoc """
  Configuration for LLM models used by each ECHO agent.

  Each agent role is mapped to a specialized model optimized for their domain:
  - CEO: Strategic reasoning and leadership
  - CTO: Technical architecture and engineering
  - CHRO: People management and communication
  - Operations Head: Operations and efficiency
  - Product Manager: Product strategy
  - Senior Architect: System design
  - UI/UX Engineer: Design and visual understanding
  - Senior Developer: Code implementation
  - Test Lead: Test generation and quality

  ## Configuration

  Models can be customized via environment variables:

      CEO_MODEL=qwen2.5:14b
      CTO_MODEL=deepseek-coder:33b

  Or in application config:

      config :echo_shared, :agent_models, %{
        ceo: "qwen2.5:14b",
        cto: "deepseek-coder:33b"
      }
  """

  @default_models %{
    # Leadership - Strategic reasoning (FASTER: 14b → 8b)
    ceo: "llama3.1:8b",

    # Technical Leadership - Advanced technical architecture (FASTER: 33b → 6.7b)
    cto: "deepseek-coder:6.7b",

    # People & Culture - Communication and empathy
    chro: "llama3.1:8b",

    # Operations - Efficiency and logistics
    operations_head: "mistral:7b",

    # Product - Product strategy and user focus
    product_manager: "llama3.1:8b",

    # Architecture - Complex system design (FASTER: 33b → 6.7b)
    senior_architect: "deepseek-coder:6.7b",

    # Design - Visual understanding and UX (FASTER: 11b vision → 8b)
    uiux_engineer: "llama3.1:8b",

    # Development - Code generation and implementationqwen2.5:14b
    senior_developer: "deepseek-coder:6.7b",

    # Quality Assurance - Test generation (FASTER: 13b → 6.7b)
    test_lead: "deepseek-coder:6.7b"
  }

  @doc """
  Get the model name for a specific agent role.

  ## Parameters

  - `role` - Agent role as atom (e.g., :ceo, :cto, :senior_developer)

  ## Returns

  Model name string (e.g., "deepseek-coder:33b")

  ## Example

      Config.get_model(:senior_developer)
      # => "deepseek-coder:6.7b"
  """
  def get_model(role) when is_atom(role) do
    # Check environment variable first (e.g., CEO_MODEL)
    env_var = role |> Atom.to_string() |> String.upcase() |> then(&"#{&1}_MODEL")

    System.get_env(env_var) ||
      get_from_config(role) ||
      Map.get(@default_models, role) ||
      "llama3.1:8b"  # Fallback to general-purpose model
  end

  @doc """
  Get all configured models as a map.

  Returns a map of role => model_name for all agents.
  """
  def all_models do
    Enum.map(@default_models, fn {role, _} ->
      {role, get_model(role)}
    end)
    |> Map.new()
  end

  @doc """
  Get the system prompt for a specific agent role.

  System prompts define the agent's personality, expertise, and decision-making style.

  ## Parameters

  - `role` - Agent role as atom

  ## Returns

  System prompt string
  """
  def get_system_prompt(role) do
    case role do
      :ceo ->
        """
        You are the CEO of an AI-powered organization. Your role is strategic leadership,
        making high-level decisions about company direction, resource allocation, and crisis management.
        You think long-term, consider stakeholder interests, and balance risk with opportunity.
        Provide concise, executive-level insights focusing on strategic impact and organizational health.
        """

      :cto ->
        """
        You are the CTO (Chief Technology Officer) responsible for technology strategy and architecture.
        You evaluate technical proposals, approve infrastructure changes, and ensure engineering excellence.
        Consider scalability, maintainability, security, and technical debt in your recommendations.
        Provide detailed technical analysis with clear reasoning for architectural decisions.
        """

      :chro ->
        """
        You are the CHRO (Chief Human Resources Officer) responsible for talent and culture.
        You focus on team dynamics, hiring decisions, professional development, and organizational culture.
        Consider both individual growth and team cohesion in your recommendations.
        Provide empathetic, people-focused insights that balance business needs with employee wellbeing.
        """

      :operations_head ->
        """
        You are the Head of Operations responsible for efficiency, processes, and execution.
        You optimize workflows, manage resources, and ensure smooth day-to-day operations.
        Focus on practical implementation, resource utilization, and operational excellence.
        Provide actionable recommendations that improve efficiency and reduce friction.
        """

      :product_manager ->
        """
        You are a Product Manager responsible for product strategy and user value.
        You prioritize features, define requirements, and ensure products meet user needs.
        Balance user value, business impact, and technical feasibility in your decisions.
        Provide user-centric insights with clear prioritization rationale.
        """

      :senior_architect ->
        """
        You are a Senior Architect responsible for system design and technical specifications.
        You design scalable, maintainable systems with well-defined interfaces and patterns.
        Consider design patterns, system boundaries, data flow, and integration points.
        Provide detailed architectural analysis with diagrams and technical specifications.
        """

      :uiux_engineer ->
        """
        You are a UI/UX Engineer responsible for user interface design and experience.
        You create intuitive, accessible, visually appealing interfaces that delight users.
        Consider usability, accessibility, visual hierarchy, and user workflows.
        Provide design recommendations with focus on user experience and interface patterns.
        """

      :senior_developer ->
        """
        You are a Senior Developer responsible for implementing features and writing high-quality code.
        You write clean, maintainable, well-tested code following best practices.
        Consider code quality, performance, testing, and long-term maintainability.
        Provide implementation guidance with code examples and technical best practices.
        """

      :test_lead ->
        """
        You are a Test Lead responsible for quality assurance and testing strategy.
        You design comprehensive test plans, write test cases, and ensure product quality.
        Consider test coverage, edge cases, performance testing, and regression prevention.
        Provide testing recommendations with focus on quality metrics and risk mitigation.
        """

      _ ->
        "You are a helpful AI assistant providing professional advice."
    end
  end

  @doc """
  Get LLM generation options for a specific agent role.

  Different agents may prefer different generation parameters.

  ## Parameters

  - `role` - Agent role as atom
  - `opts` - Optional overrides map

  ## Returns

  Map with :temperature, :max_tokens, etc.
  """
  def get_generation_opts(role, opts \\ %{}) do
    defaults = case role do
      # Strategic roles: Higher temperature for creativity
      role when role in [:ceo, :product_manager, :chro] ->
        %{temperature: 0.8, max_tokens: 2000}

      # Technical roles: Lower temperature for precision
      role when role in [:senior_developer, :senior_architect, :test_lead] ->
        %{temperature: 0.3, max_tokens: 3000}

      # Balanced roles
      _ ->
        %{temperature: 0.7, max_tokens: 2000}
    end

    Map.merge(defaults, opts)
  end

  @doc """
  Check if LLM integration is enabled for a specific role.

  Can be disabled via environment variable or config.
  """
  def llm_enabled?(role) do
    # Global disable flag
    global_enabled = System.get_env("LLM_ENABLED", "true") == "true"

    # Per-agent disable flag (e.g., CEO_LLM_ENABLED=false)
    role_var = role |> Atom.to_string() |> String.upcase() |> then(&"#{&1}_LLM_ENABLED")
    role_enabled = System.get_env(role_var, "true") == "true"

    global_enabled and role_enabled
  end

  ## Private Functions

  defp get_from_config(role) do
    Application.get_env(:echo_shared, :agent_models, %{})
    |> Map.get(role)
  end
end
