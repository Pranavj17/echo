# Why ElixirLS Causes Database Connection Exhaustion

## The Problem in Simple Terms

**ElixirLS compiles ALL your agent applications** whenever you open VS Code or save a file. When each application compiles, it **tries to start**, which means **connecting to the database**. This happens even though you're not actually running the agents.

---

## The Technical Details

### What Happens When You Open VS Code with ECHO Project

1. **ElixirLS Starts** (2-3 BEAM processes)
   ```
   PID 9753: ElixirLS on Erlang 26.2
   PID 9754: ElixirLS on Erlang 27.0
   ```

2. **ElixirLS Compiles Your Code**
   - Compiles `shared/` library
   - Compiles ALL 9 agents: CEO, CTO, CHRO, Product Manager, Senior Architect, Operations Head, UI/UX Engineer, Senior Developer, Test Lead

3. **Each Agent's Application Module Runs**

   When Elixir compiles an application, it evaluates the code, including:

   ```elixir
   # agents/ceo/lib/ceo/application.ex
   defmodule Ceo.Application do
     use Application

     def start(_type, _args) do
       children = [
         EchoShared.Repo,  # ← This tries to connect to PostgreSQL!
         {Redix, name: :redix},
         # ... more children
       ]

       Supervisor.start_link(children, opts)
     end
   end
   ```

   **The problem**: `EchoShared.Repo` in the supervision tree means **"connect to PostgreSQL"**.

4. **Connection Pool Created for Each Compilation**

   Each agent that ElixirLS compiles creates:
   - `pool_size: 1` connection to PostgreSQL (after our fix, was 10 before!)
   - Connection to Redis
   - Health Monitor (which tries to query database every 14 seconds)

---

## The Math: Why It Breaks

### Scenario: ElixirLS + 6 Training Agents

#### When VS Code is OPEN:

```
ElixirLS Connections:
  - ElixirLS Process 1: compiling shared + 9 agents
    └─ Each agent app starts → 9 applications × 1 connection = 9 connections
  - ElixirLS Process 2: same thing on different Erlang version
    └─ 9 applications × 1 connection = 9 connections

  ElixirLS Total: ~18 connections (can spike to 30+ during active compilation)

Your Training Agents:
  - CEO agent: 1 connection
  - CTO agent: 1 connection
  - CHRO agent: 1 connection
  - Product Manager: 1 connection
  - Senior Architect: 1 connection
  - Operations Head: 1 connection

  Training Total: 6 connections

TOTAL SIMULTANEOUS: 18 + 6 = 24+ connections
```

#### When Agents Start Simultaneously:

During the startup window (first 10-15 seconds), each agent tries to:
1. Create connection pool (1 connection)
2. Query for missed messages (uses the 1 connection)
3. Start health monitor (uses the 1 connection)

**But**: PostgreSQL connection pool has a **queue**. If all 6 agents + 18 ElixirLS connections try to query at the same time:

```
Available connections: 300 (max_connections)
Active connections: 18 (ElixirLS)
Trying to connect: 6 agents × ~2 queries each = 12 attempts

Queue timeout: 4000ms (default)

What happens:
- Agent 1 (CEO): Connects successfully ✅
- Agent 2 (CTO): Queued... timeout after 4s ❌
- Agent 3 (CHRO): Queued... timeout after 4s ❌
- Agent 4 (PM): Queued... timeout after 4s ❌
- Agent 5 (SA): Queued... timeout after 4s ❌
- Agent 6 (Ops): Queued... timeout after 4s ❌
```

The queue fills up because each agent is holding its connection while trying to run queries, and new queries can't get connections.

---

## Why Our Fixes Help (But Don't Solve Completely)

### 1. ✅ Reduced pool_size from 10 to 1
**Before**: 9 agents × 10 connections = 90 connections from ElixirLS alone!
**After**: 9 agents × 1 connection = 9 connections from ElixirLS
**Improvement**: 81 fewer connections

### 2. ✅ Staggered Agent Startup (2-second delays)
**Before**: All 6 agents start simultaneously, compete for connections
**After**: Agents start sequentially, each gets time to initialize
**Improvement**: Prevents queue congestion

### 3. ✅ Async Database Catchup with Timeout
**Before**: If catchup query times out, agent crashes
**After**: Agent starts anyway, skips catchup
**Improvement**: Agents don't fail on connection issues

### 4. ✅ Resilient Health Monitor
**Before**: Health monitor crashes agents when DB query fails
**After**: Health monitor logs warning, continues with degraded service
**Improvement**: Agents stay alive

### But Still Not Perfect Because:

ElixirLS **keeps recompiling** whenever you:
- Save a file
- Switch git branches
- Open a new terminal
- Run Mix commands

Each recompilation can briefly spike connections.

---

## Why PostgreSQL Has Connection Limits

PostgreSQL creates a **separate backend process** for each connection. This is not like HTTP where connections are cheap - each connection is a full OS process.

**Memory cost per connection**: ~10MB
**With 300 connections**: ~3GB of RAM just for connection processes!

Additionally, each connection has:
- TCP socket
- Authentication state
- Transaction state
- Query buffers
- Prepared statement cache

**This is why** PostgreSQL limits connections and why connection pooling exists.

---

## The Real-World Impact

### What You Saw in Logs:

```
[error] Postgrex.Protocol (#PID<0.177.0>) failed to connect:
  ** (DBConnection.ConnectionError) tcp recv (idle): closed
```

**Translation**:
1. Agent tried to connect to PostgreSQL
2. Connection pool was full (all 1 connection in use by another query)
3. Query waited in queue for 4000ms (default timeout)
4. Timeout expired, connection was dropped
5. Agent's initialization failed

### Why It Says "tcp recv (idle): closed"

This means:
1. Agent **did** get a TCP connection to PostgreSQL
2. But PostgreSQL **closed it** because max_connections was reached
3. The connection was "idle" (waiting for auth) when it was closed

---

## Why ElixirLS Doesn't Know About This

ElixirLS is a **general-purpose** language server. It assumes:
- Your app might not use a database
- If it does, database is optional for compilation
- Compilation should succeed without runtime dependencies

**But ECHO's architecture**:
- Database is **required** (in supervision tree)
- Apps automatically start when compiled (OTP behavior)
- No way to disable this during ElixirLS analysis

---

## Solutions Ranked by Effectiveness

### 🥇 Best: Close VS Code During Training
```bash
# Kill ElixirLS
pkill -9 -f "elixir-ls"

# Verify
ps aux | grep elixir-ls  # Should be empty

# Run training
./day2_training_v2.sh
```

**Pros**: 100% eliminates the issue
**Cons**: Can't edit code while training runs

### 🥈 Good: Disable ElixirLS Extension
```
VS Code → Extensions → ElixirLS → Disable
Reload VS Code
```

**Pros**: Can keep VS Code open
**Cons**: Lose autocomplete, go-to-definition, etc.

### 🥉 Okay: Increase Connection Pool
```elixir
# shared/config/dev.exs
pool_size: 5  # Instead of 1
```

**Pros**: Reduces timeout errors
**Cons**: Uses more memory, doesn't solve root cause

### ❌ Won't Work: Increase max_connections to 1000+

**Why not**:
- Each connection = ~10MB RAM
- 1000 connections = 10GB RAM just for PostgreSQL
- System becomes unstable
- Doesn't solve queue contention

---

## The Deeper Architectural Issue

### Why ECHO Has This Problem

ECHO's design puts **EchoShared.Repo** in every agent's supervision tree:

```elixir
# This means: "Start database connection pool when application starts"
children = [
  EchoShared.Repo,  # ← Always tries to connect
  # ... other children
]
```

**Alternative Design** (for future consideration):

```elixir
# Lazy connection: Only connect when first message arrives
children = [
  {EchoShared.LazyRepo, start_on_demand: true},
  # ... other children
]
```

This would mean:
- ElixirLS compilation doesn't create connections
- Agents only connect when they receive first message
- Much lower baseline connection usage

**Trade-off**: More complex initialization logic

---

## Current Recommendation

### For Development:
1. **Always close VS Code before running training scripts**
2. Edit code → Save → Close VS Code → Run training → Check results
3. If you need to keep VS Code open: Disable ElixirLS extension

### For Production (Future):
1. Consider lazy database connection pattern
2. Use connection pooler like PgBouncer
3. Separate compilation environment from runtime environment

---

## Verification Commands

### Check ElixirLS is Stopped:
```bash
ps aux | grep elixir-ls | grep -v grep
# Should return nothing
```

### Check BEAM Processes:
```bash
ps aux | grep beam.smp | grep -v grep | wc -l
# Should be 0 (no agents running) or 6 (training agents only)
```

### Check Database Connections:
```bash
docker exec echo_postgres psql -U postgres -c "
  SELECT application_name, count(*) as connections
  FROM pg_stat_activity
  GROUP BY application_name
  ORDER BY connections DESC;"
```

**Expected with ElixirLS OFF and agents running**:
```
application_name | connections
------------------+-------------
                  |           6-10
```

**Warning sign (ElixirLS is ON)**:
```
application_name | connections
------------------+-------------
                  |          20-40
```

---

## Summary

**ElixirLS exhausts database connections because**:
1. It compiles all 9 ECHO agents when VS Code opens
2. Each agent's Application module starts a database connection pool
3. Each compilation creates 1 connection × 9 agents = 9 connections
4. ElixirLS often runs 2-3 processes = 18-27 connections baseline
5. When training agents start, they compete with ElixirLS for connections
6. Connection pool queue fills up, timeouts occur, agents fail to initialize

**The fix is simple**: **Close VS Code before running training**.

**Long-term solution**: Redesign agent architecture to use lazy database connections.

---

**Last Updated**: 2025-11-06 11:00 UTC
**Issue Severity**: High (blocks development workflow)
**Workaround Available**: Yes (close VS Code)
**Permanent Fix Needed**: Yes (lazy connections or PgBouncer)
