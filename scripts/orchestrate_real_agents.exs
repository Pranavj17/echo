#!/usr/bin/env elixir

# ECHO Real Agent Orchestrator
#
# This orchestrator:
# 1. Assumes agents are already running (started by run_day1_with_agents.sh)
# 2. Subscribes to receive responses from agents
# 3. Sends real JSON-RPC messages via Redis
# 4. Waits for agent responses
# 5. Coordinates multi-agent workflows

defmodule RealAgentOrchestrator do
  require Logger

  def run() do
    IO.puts ""
    IO.puts String.duplicate("=", 80)
    IO.puts "ECHO Real Agent Orchestrator"
    IO.puts "Real-time agent communication via Redis"
    IO.puts String.duplicate("=", 80)
    IO.puts ""

    # Start the ECHO shared application
    {:ok, _} = Application.ensure_all_started(:echo_shared)

    # Connect to Redis for responses
    {:ok, pubsub} = Redix.PubSub.start_link()
    {:ok, redix} = Redix.start_link()

    # Subscribe to orchestrator channel for responses
    Redix.PubSub.subscribe(pubsub, "messages:orchestrator", self())

    IO.puts "✓ Connected to Redis"
    IO.puts "✓ Subscribed to messages:orchestrator"
    IO.puts ""
    IO.puts "Make sure agents are running: ./scripts/run_day1_with_agents.sh"
    IO.puts ""
    IO.puts "Press Enter when agents are ready..."
    IO.gets("")

    IO.puts ""
    IO.puts String.duplicate("=", 80)
    IO.puts "Starting Curiosity Workflow with Real Agents"
    IO.puts String.duplicate("=", 80)
    IO.puts ""

    # Run the curiosity workflow
    run_curiosity_workflow(redix, pubsub)
  end

  defp run_curiosity_workflow(redix, pubsub) do
    # Phase 1: CEO sets strategic vision
    IO.puts "Phase 1: CEO Setting Strategic Vision"
    IO.puts String.duplicate("-", 80)

    msg_id_1 = send_message(redix, "ceo", "set_company_vision", %{
      vision_statement: "Explore how AI systems can develop genuine curiosity as a core capability",
      strategic_goals: [
        "Understand the nature of curiosity in AI",
        "Design curiosity mechanisms",
        "Implement a curiosity-driven learning system",
        "Measure curiosity in our AI agents"
      ],
      budget_allocation: 500_000,
      timeline: "12 weeks",
      success_metrics: [
        "AI agents ask unprompted questions",
        "AI agents explore beyond given tasks",
        "AI agents demonstrate learning initiative"
      ],
      reasoning: "Curiosity is fundamental to intelligence. If we can make AI curious, we unlock autonomous learning and innovation."
    })

    case wait_for_response(pubsub, "ceo", msg_id_1, 15_000) do
      {:ok, response} ->
        IO.puts "✓ CEO Response received!"
        IO.puts "  Result: #{inspect(response["result"], pretty: true, limit: :infinity)}"
        IO.puts ""

        # Phase 2: Leadership discussion (parallel!)
        IO.puts "Phase 2: Leadership Discussion (3 agents in parallel)"
        IO.puts String.duplicate("-", 80)

        msg_id_2 = send_message(redix, "cto", "evaluate_technical_feasibility", %{
          agenda: "AI Curiosity Implementation",
          questions_to_explore: [
            "What defines curiosity in computational terms?",
            "Can we measure information gaps that drive curiosity?",
            "How do we encode intrinsic motivation?"
          ],
          technical_concerns: [
            "Computational cost of curiosity mechanisms",
            "Preventing curiosity from becoming chaotic exploration",
            "Safety boundaries for curious AI"
          ]
        })

        msg_id_3 = send_message(redix, "chro", "assess_team_capabilities", %{
          agenda: "AI Curiosity Research",
          required_skills: [
            "Reinforcement learning expertise",
            "Information theory knowledge",
            "Cognitive science background"
          ],
          team_development_needs: [
            "Training on curiosity-driven learning algorithms",
            "Workshop on intrinsic motivation in AI"
          ]
        })

        # Wait for both responses
        wait_for_multiple_responses(pubsub, ["cto", "chro"], [msg_id_2, msg_id_3], 15_000)

        IO.puts ""
        IO.puts "✓ All agents responded!"
        IO.puts ""
        IO.puts "Workflow demonstrated real agent-to-agent communication! 🎉"

      {:error, :timeout} ->
        IO.puts "✗ Timeout waiting for CEO response"
        IO.puts "  Check agent logs: logs/day1_*/ceo.log"
        System.halt(1)
    end
  end

  defp send_message(redix, agent, subject, content) do
    msg_id = "msg_#{:erlang.unique_integer([:positive])}"

    message = %{
      "id" => msg_id,
      "from" => "orchestrator",
      "to" => agent,
      "type" => "request",
      "subject" => subject,
      "content" => content,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    channel = "messages:#{agent}"
    {:ok, _} = Redix.command(redix, ["PUBLISH", channel, Jason.encode!(message)])

    IO.puts "→ Sent to #{String.upcase(agent)}: #{subject}"

    msg_id
  end

  defp wait_for_response(pubsub, agent, msg_id, timeout) do
    IO.puts "  Waiting for #{agent} response..."

    receive do
      {:redix_pubsub, ^pubsub, :message, %{channel: "messages:orchestrator", payload: payload}} ->
        case Jason.decode(payload) do
          {:ok, %{"from" => ^agent, "in_reply_to" => ^msg_id, "type" => "response"} = response} ->
            {:ok, response}

          {:ok, %{"from" => ^agent, "in_reply_to" => ^msg_id, "type" => "error"} = error} ->
            IO.puts "  ✗ Error from #{agent}: #{error["error"]["message"]}"
            {:error, error}

          _ ->
            # Not the message we're waiting for
            wait_for_response(pubsub, agent, msg_id, timeout)
        end
    after
      timeout ->
        {:error, :timeout}
    end
  end

  defp wait_for_multiple_responses(pubsub, agents, msg_ids, timeout) do
    responses = Enum.map(agents, fn _agent -> nil end)
    wait_for_multiple_responses_loop(pubsub, agents, msg_ids, responses, timeout, System.monotonic_time(:millisecond))
  end

  defp wait_for_multiple_responses_loop(_pubsub, agents, _msg_ids, responses, _timeout, _start_time) when length(responses) == length(agents) do
    # All responses received
    Enum.zip(agents, responses)
    |> Enum.each(fn {agent, response} ->
      if response do
        IO.puts "✓ #{String.upcase(agent)} Response received!"
      end
    end)
    :ok
  end

  defp wait_for_multiple_responses_loop(pubsub, agents, msg_ids, responses, timeout, start_time) do
    elapsed = System.monotonic_time(:millisecond) - start_time
    remaining = timeout - elapsed

    if remaining <= 0 do
      IO.puts "✗ Timeout waiting for responses"
      :timeout
    else
      receive do
        {:redix_pubsub, ^pubsub, :message, %{payload: payload}} ->
          case Jason.decode(payload) do
            {:ok, %{"from" => agent, "type" => "response"} = response} ->
              case Enum.find_index(agents, &(&1 == agent)) do
                nil ->
                  # Not an agent we're waiting for
                  wait_for_multiple_responses_loop(pubsub, agents, msg_ids, responses, timeout, start_time)

                index ->
                  # Update responses list
                  new_responses = List.replace_at(responses, index, response)
                  IO.puts "✓ #{String.upcase(agent)} responded"
                  wait_for_multiple_responses_loop(pubsub, agents, msg_ids, new_responses, timeout, start_time)
              end

            _ ->
              wait_for_multiple_responses_loop(pubsub, agents, msg_ids, responses, timeout, start_time)
          end
      after
        remaining ->
          IO.puts "✗ Timeout"
          :timeout
      end
    end
  end
end

# Run the orchestrator
RealAgentOrchestrator.run()
