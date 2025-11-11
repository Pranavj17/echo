# Session Persistence Bug - Root Cause Analysis

**Issue:** Sessions created in one `mix run` cannot be accessed in another `mix run`

**Evidence:**
- ✅ Session creation works: `session=ceo_1762842800_145484,turn=1,tokens=793`
- ❌ Continuation fails: `FAIL:continuation` with `:session_not_found`
- ✅ Works perfectly WITHIN the same process (debug_session.exs succeeded)

---

## Possible Root Causes & Fix Probabilities

### 1. **ETS Table Lifecycle Issue** 🔴 HIGH PROBABILITY

**Probability:** 85%

**Root Cause:**
- ETS tables are **process-local** in BEAM VM
- Each `mix run` starts a **NEW BEAM VM instance**
- Session GenServer creates ETS table `:llm_sessions`
- When Mix process exits → **ETS table destroyed**
- Next `mix run` → New GenServer → **Fresh empty ETS table**

**Evidence:**
```elixir
# apps/echo_shared/lib/echo_shared/llm/session.ex:328
:ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
# This creates in-memory table - NO persistence to disk
```

**Fix Options:**

#### Option A: PostgreSQL Session Storage (RECOMMENDED)
**Probability of Success:** 70%
**Effort:** Medium (2-3 hours)
**Pros:**
- ✅ True persistence across restarts
- ✅ Leverages existing infrastructure
- ✅ Production-ready (ACID compliance)
- ✅ Aligns with ECHO architecture (everything in DB)
- ✅ Session history queryable/analyzable
- ✅ Supports multi-instance deployments

**Cons:**
- ⚠️ Slightly slower than ETS (~5-10ms per query vs <1ms)
- ⚠️ Requires migration

**Implementation:**
1. Create `llm_sessions` table in PostgreSQL
2. Add `Session` schema with Ecto
3. Replace ETS calls with Repo calls
4. Keep cleanup logic (cron job or TTL)

#### Option B: DETS (Disk-based ETS)
**Probability of Success:** 50%
**Effort:** Low (30 minutes)
**Pros:**
- ✅ Simple drop-in replacement for ETS
- ✅ Automatic disk persistence

**Cons:**
- ❌ Slower than ETS (10-50x)
- ❌ File corruption risk
- ❌ Not suitable for production
- ❌ Single-file bottleneck
- ❌ Needs manual file management

#### Option C: Mnesia
**Probability of Success:** 60%
**Effort:** High (4-6 hours)
**Pros:**
- ✅ Distributed database built into Erlang
- ✅ Fast like ETS with persistence

**Cons:**
- ❌ Overkill for this use case
- ❌ Complex setup and clustering
- ❌ Another database to manage

---

### 2. **GenServer Not Starting in Test Context**

**Probability:** 5%

**Root Cause:**
- Session GenServer might not be supervised in test environment
- Application supervision tree not starting

**Evidence AGAINST This:**
```
✅ Logs show: "LLM Session manager started"
✅ Verification passed: Application supervision check
```

**Fix:** Not needed - already working

---

### 3. **ETS Table Configuration Issue**

**Probability:** 8%

**Root Cause:**
- Table not `public` (can't access from other processes)
- Table not `named_table` (can't find by name)
- Race condition on table creation

**Evidence AGAINST This:**
```elixir
:ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
                       ^^^^^^^^^^^^^^^^      ^^^^^^^
# Correct configuration
```

**Fix:** Not needed - configuration is correct

---

### 4. **Session Cleanup Too Aggressive**

**Probability:** 2%

**Root Cause:**
- Cleanup cron job runs too frequently
- Session deleted before continuation attempt

**Evidence AGAINST This:**
```elixir
@session_timeout_ms :timer.hours(1)      # 1 hour
@cleanup_interval_ms :timer.minutes(15)  # Every 15 minutes
# Test runs in < 5 minutes - should not trigger cleanup
```

**Fix:** Not needed - cleanup is fine

---

## Recommended Fix: PostgreSQL Session Storage

**Confidence:** 70% (HIGH)
**Effort:** Medium
**Impact:** Solves persistence + enables new features

### Implementation Plan

#### Step 1: Create Migration
```elixir
# apps/echo_shared/priv/repo/migrations/XXXXXX_create_llm_sessions.exs

defmodule EchoShared.Repo.Migrations.CreateLlmSessions do
  use Ecto.Migration

  def change do
    create table(:llm_sessions, primary_key: false) do
      add :session_id, :string, primary_key: true
      add :agent_role, :string, null: false
      add :startup_context, :text
      add :conversation_history, :jsonb, default: "[]"
      add :turn_count, :integer, default: 0
      add :total_tokens, :integer, default: 0
      add :created_at, :utc_datetime
      add :last_query_at, :utc_datetime
    end

    create index(:llm_sessions, [:agent_role])
    create index(:llm_sessions, [:last_query_at])
  end
end
```

#### Step 2: Create Schema
```elixir
# apps/echo_shared/lib/echo_shared/schemas/llm_session.ex

defmodule EchoShared.Schemas.LlmSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:session_id, :string, autogenerate: false}
  schema "llm_sessions" do
    field :agent_role, :string
    field :startup_context, :string
    field :conversation_history, {:array, :map}, default: []
    field :turn_count, :integer, default: 0
    field :total_tokens, :integer, default: 0
    field :created_at, :utc_datetime
    field :last_query_at, :utc_datetime
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:session_id, :agent_role, :startup_context,
                    :conversation_history, :turn_count, :total_tokens,
                    :created_at, :last_query_at])
    |> validate_required([:session_id, :agent_role])
  end
end
```

#### Step 3: Update Session Module
```elixir
# Replace ETS calls with Repo calls

# OLD:
:ets.insert(@table_name, {session_id, session})

# NEW:
%LlmSession{}
|> LlmSession.changeset(session)
|> Repo.insert()

# OLD:
case :ets.lookup(@table_name, session_id) do
  [{^session_id, session}] -> session
  [] -> nil
end

# NEW:
Repo.get(LlmSession, session_id)
```

#### Step 4: Update Cleanup Logic
```elixir
# Replace ETS scan with DB query

# OLD:
:ets.tab2list(@table_name)
|> Enum.filter(fn {_id, session} ->
  DateTime.compare(session.last_query_at, cutoff) == :lt
end)

# NEW:
from(s in LlmSession,
  where: s.last_query_at < ^cutoff
)
|> Repo.delete_all()
```

### Benefits of This Fix

1. **✅ Solves the bug** - Sessions persist across restarts
2. **✅ Production-ready** - ACID compliance, backups included
3. **✅ Enables features:**
   - Session history analysis
   - Multi-instance deployments (shared sessions)
   - Session resume after app restart
   - Long-running sessions (days/weeks)
4. **✅ Minimal performance impact** - ~5ms extra per query (acceptable)
5. **✅ Consistent architecture** - Everything in PostgreSQL

---

## Alternative: Quick Fix (Not Recommended)

If you want sessions to work ONLY within a single process:

**Run agents in continuous mode:**
```bash
# Start agent as long-running process
cd apps/ceo && iex -S mix

# Now all session_consult calls work in this iex session
```

**Pros:**
- ✅ Zero code changes
- ✅ Works immediately

**Cons:**
- ❌ Doesn't solve the real problem
- ❌ Sessions lost on restart
- ❌ Not production-ready
- ❌ Testing is awkward

---

## Decision Matrix

| Solution | Probability | Effort | Production Ready | Recommended |
|----------|-------------|--------|------------------|-------------|
| PostgreSQL | 70% | Medium | ✅ Yes | ✅ **BEST** |
| DETS | 50% | Low | ❌ No | ❌ No |
| Mnesia | 60% | High | ⚠️ Complex | ❌ No |
| Continuous mode | 90% | None | ⚠️ Workaround | ⚠️ Temporary |

---

## Recommendation

**Implement PostgreSQL session storage** because:
1. Highest confidence for production (70%)
2. Solves persistence properly
3. Enables future features (session analysis, multi-instance)
4. Aligns with ECHO architecture
5. ~5ms performance impact is acceptable for session operations

**Estimated time:** 2-3 hours
**Risk:** Low (well-understood technology)
**Impact:** HIGH (fixes bug + adds production capabilities)
