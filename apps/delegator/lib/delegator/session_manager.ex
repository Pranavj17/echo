defmodule Delegator.SessionManager do
  @moduledoc """
  Manages delegator session state: active agents, task context, and history.

  A session represents a single interaction with Claude Desktop where
  specific agents are spawned to accomplish a task.

  ## Usage

      # Start new session
      {:ok, session} = SessionManager.start_session(:development, "Fix authentication bug")

      # Get current session
      session = SessionManager.get_session()

      # Add task to history
      SessionManager.add_task("Implement password reset")

      # Update session context
      SessionManager.update_context(%{branch: "feature/auth", files_changed: ["auth.ex"]})

      # End session and cleanup
      SessionManager.end_session()
  """

  use GenServer
  require Logger

  defstruct [
    :session_id,
    :task_category,
    :active_agents,
    :started_at,
    :task_history,
    :context,
    :metadata
  ]

  @type t :: %__MODULE__{
          session_id: String.t() | nil,
          task_category: atom() | nil,
          active_agents: [atom()],
          started_at: DateTime.t() | nil,
          task_history: [String.t()],
          context: map(),
          metadata: map()
        }

  @type category ::
          :strategic
          | :technical
          | :development
          | :hr
          | :operations
          | :product
          | :quick_fix

  ## Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc """
  Start a new session with the specified category and description.

  ## Parameters

    * `category` - Task category (e.g., :development, :technical)
    * `description` - Brief description of the task
    * `opts` - Optional metadata

  ## Examples

      {:ok, session} = SessionManager.start_session(
        :development,
        "Fix authentication bug",
        user: "pranav@example.com"
      )
  """
  @spec start_session(category(), String.t(), keyword()) :: {:ok, t()} | {:error, :already_started}
  def start_session(category, description, opts \\ []) do
    GenServer.call(__MODULE__, {:start_session, category, description, opts})
  end

  @doc """
  End the current session and cleanup.

  Returns session summary statistics.

  ## Examples

      {:ok, summary} = SessionManager.end_session()
      # %{
      #   session_id: "session_abc123",
      #   duration_seconds: 1234,
      #   agents_used: [:ceo, :cto],
      #   tasks_completed: 5
      # }
  """
  @spec end_session() :: {:ok, map()} | {:error, :no_session}
  def end_session do
    GenServer.call(__MODULE__, :end_session)
  end

  @doc """
  Get the current session state.

  Returns `nil` if no session is active.

  ## Examples

      case SessionManager.get_session() do
        %SessionManager{} = session ->
          IO.inspect(session.active_agents)
        nil ->
          IO.puts("No active session")
      end
  """
  @spec get_session() :: t() | nil
  def get_session do
    GenServer.call(__MODULE__, :get_session)
  end

  @doc """
  Add a task to the session history.

  ## Examples

      SessionManager.add_task("Implement password reset endpoint")
  """
  @spec add_task(String.t()) :: :ok | {:error, :no_session}
  def add_task(task_description) do
    GenServer.call(__MODULE__, {:add_task, task_description})
  end

  @doc """
  Update session context with new information.

  Context can include things like: branch name, files changed,
  decisions made, etc.

  ## Examples

      SessionManager.update_context(%{
        branch: "feature/auth",
        files_modified: ["lib/auth.ex", "test/auth_test.exs"],
        tests_passing: true
      })
  """
  @spec update_context(map()) :: :ok | {:error, :no_session}
  def update_context(updates) do
    GenServer.call(__MODULE__, {:update_context, updates})
  end

  @doc """
  Register that an agent was spawned for this session.

  ## Examples

      SessionManager.agent_spawned(:ceo)
  """
  @spec agent_spawned(atom()) :: :ok | {:error, :no_session}
  def agent_spawned(role) do
    GenServer.call(__MODULE__, {:agent_spawned, role})
  end

  @doc """
  Register that an agent was shut down.

  ## Examples

      SessionManager.agent_shutdown(:ceo)
  """
  @spec agent_shutdown(atom()) :: :ok | {:error, :no_session}
  def agent_shutdown(role) do
    GenServer.call(__MODULE__, {:agent_shutdown, role})
  end

  @doc """
  Check if a session is currently active.

  ## Examples

      if SessionManager.session_active?() do
        # Session is running
      end
  """
  @spec session_active?() :: boolean()
  def session_active? do
    case get_session() do
      nil -> false
      %__MODULE__{} -> true
    end
  end

  ## Server Callbacks

  @impl true
  def init(_) do
    {:ok, nil}
  end

  @impl true
  def handle_call({:start_session, category, description, opts}, _from, state) do
    case state do
      nil ->
        session = %__MODULE__{
          session_id: generate_session_id(),
          task_category: category,
          active_agents: [],
          started_at: DateTime.utc_now(),
          task_history: [description],
          context: %{},
          metadata: Enum.into(opts, %{})
        }

        Logger.info("Session started",
          session_id: session.session_id,
          category: category,
          description: description
        )

        {:reply, {:ok, session}, session}

      %__MODULE__{} = _existing_session ->
        {:reply, {:error, :already_started}, state}
    end
  end

  @impl true
  def handle_call(:end_session, _from, state) do
    case state do
      nil ->
        {:reply, {:error, :no_session}, nil}

      %__MODULE__{} = session ->
        duration = DateTime.diff(DateTime.utc_now(), session.started_at, :second)

        summary = %{
          session_id: session.session_id,
          duration_seconds: duration,
          agents_used: session.active_agents,
          tasks_completed: length(session.task_history),
          category: session.task_category
        }

        Logger.info("Session ended",
          session_id: session.session_id,
          duration_seconds: duration,
          agents_used: session.active_agents,
          tasks_completed: length(session.task_history)
        )

        {:reply, {:ok, summary}, nil}
    end
  end

  @impl true
  def handle_call(:get_session, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:add_task, task_description}, _from, state) do
    case state do
      nil ->
        {:reply, {:error, :no_session}, nil}

      %__MODULE__{} = session ->
        updated = %{session | task_history: [task_description | session.task_history]}
        {:reply, :ok, updated}
    end
  end

  @impl true
  def handle_call({:update_context, updates}, _from, state) do
    case state do
      nil ->
        {:reply, {:error, :no_session}, nil}

      %__MODULE__{} = session ->
        updated = %{session | context: Map.merge(session.context, updates)}
        {:reply, :ok, updated}
    end
  end

  @impl true
  def handle_call({:agent_spawned, role}, _from, state) do
    case state do
      nil ->
        {:reply, {:error, :no_session}, nil}

      %__MODULE__{} = session ->
        if role in session.active_agents do
          {:reply, :ok, session}
        else
          updated = %{session | active_agents: [role | session.active_agents]}
          Logger.debug("Agent spawned for session", role: role, session_id: session.session_id)
          {:reply, :ok, updated}
        end
    end
  end

  @impl true
  def handle_call({:agent_shutdown, role}, _from, state) do
    case state do
      nil ->
        {:reply, {:error, :no_session}, nil}

      %__MODULE__{} = session ->
        updated = %{session | active_agents: List.delete(session.active_agents, role)}
        Logger.debug("Agent shutdown for session", role: role, session_id: session.session_id)
        {:reply, :ok, updated}
    end
  end

  ## Private Functions

  defp generate_session_id do
    timestamp = DateTime.utc_now() |> DateTime.to_unix(:millisecond)
    random = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
    "session_#{timestamp}_#{random}"
  end
end
