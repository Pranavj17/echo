#!/usr/bin/env python3
"""
Simple script to add session_consult tool to all ECHO agents.
"""

import re
import os
import subprocess

AGENTS = {
    "cto": "cto",
    "chro": "chro",
    "operations_head": "operations_head",
    "product_manager": "product_manager",
    "senior_architect": "senior_architect",
    "uiux_engineer": "uiux_engineer",
    "senior_developer": "senior_developer",
    "test_lead": "test_lead",
}

TOOL_DEF_TEMPLATE = '''      },
      %{
        name: "session_consult",
        description: """
        Query the AI assistant with conversation memory (LocalCode-style).

        Maintains multi-turn conversations with automatic context injection:
        - Your role, responsibilities, and authority limits
        - Recent decisions and messages (last 5 each)
        - Current system status (PostgreSQL, Redis, Ollama)
        - Git context (branch, last commit)
        - Conversation history (last 5 turns)

        Perfect for exploratory questions, decision analysis with iterative thinking,
        and strategy planning with follow-up questions.
        """,
        inputSchema: %{
          type: "object",
          properties: %{
            question: %{
              type: "string",
              description: "The question to ask the AI assistant",
              minLength: 1
            },
            session_id: %{
              type: "string",
              description: "Session ID to continue conversation (optional, omit for new session)"
            },
            context: %{
              type: "string",
              description: "Additional context for this specific query (optional)"
            }
          },
          required: ["question"]
        }
      }'''

def add_session_consult(agent_dir, role):
    """Add session_consult tool to an agent."""
    file_path = f"apps/{agent_dir}/lib/{agent_dir}.ex"

    if not os.path.exists(file_path):
        print(f"⚠️  Skipping {agent_dir}: File not found")
        return False

    with open(file_path, 'r') as f:
        content = f.read()

    # Check if already has session_consult
    if '"session_consult"' in content:
        print(f"   ✓ {agent_dir} already has session_consult")
        return True

    # Backup
    with open(f"{file_path}.backup", 'w') as f:
        f.write(content)

    #Step 1: Add tool definition before closing ]
    # Find the last tool in the list (look for pattern "}\n    ]\n  end" in tools function)
    tool_pattern = r'(\s+})\s+(\]\s+end\s+@impl true\s+def execute_tool)'

    if not re.search(tool_pattern, content):
        print(f"   ❌ {agent_dir}: Could not find tools list end")
        return False

    content = re.sub(
        tool_pattern,
        rf'\1,{TOOL_DEF_TEMPLATE}\n    \2',
        content
    )

    # Step 2: Add execute_tool handler before catch-all handler
    handler_code = f'''
  def execute_tool("session_consult", args) do
    question = Map.fetch!(args, "question")
    session_id = Map.get(args, "session_id")
    context = Map.get(args, "context")

    opts = if context, do: [context: context], else: []

    case DecisionHelper.consult_session(:{role}, session_id, question, opts) do
      {{:ok, result}} ->
        response = format_session_response(result)
        {{:ok, response}}

      {{:error, :llm_disabled}} ->
        {{:error, "LLM is disabled for {agent_dir}. Enable with LLM_ENABLED=true or {agent_dir.upper()}_LLM_ENABLED=true"}}

      {{:error, :session_not_found}} ->
        {{:error, "Session not found: #{{session_id}}. It may have expired after 1 hour of inactivity."}}

      {{:error, reason}} ->
        {{:error, "AI consultation failed: #{{inspect(reason)}}"}}
    end
  end
'''

    # Find catch-all handler: def execute_tool(name, _args) do
    catchall_pattern = r'(\s+def execute_tool\(name, _args\) do)'
    content = re.sub(catchall_pattern, rf'{handler_code}\1', content)

    # Step 3: Add format_session_response helper before module end
    helper_code = f'''
  defp format_session_response(result) do
    model = EchoShared.LLM.Config.get_model(:{role})

    base = %{{
      "response" => result.response,
      "session_id" => result.session_id,
      "turn_count" => result.turn_count,
      "estimated_tokens" => result.total_tokens,
      "model" => model,
      "agent" => "{agent_dir}"
    }}

    if result.warnings != [] do
      Map.put(base, "warnings", result.warnings)
    else
      base
    end
  end
'''

    # Add before final "end"
    content = content.rstrip() + helper_code + "\nend\n"

    # Write modified content
    with open(file_path, 'w') as f:
        f.write(content)

    # Compile to check
    result = subprocess.run(
        ['mix', 'compile'],
        cwd=f"apps/{agent_dir}",
        capture_output=True,
        text=True
    )

    if result.returncode == 0 and 'Generated' in result.stdout:
        print(f"   ✅ {agent_dir}: Success!")
        os.remove(f"{file_path}.backup")
        return True
    else:
        print(f"   ❌ {agent_dir}: Compilation failed!")
        print(f"      {result.stderr[:200]}")
        # Restore backup
        with open(f"{file_path}.backup", 'r') as f:
            with open(file_path, 'w') as out:
                out.write(f.read())
        return False

def main():
    print("=" * 50)
    print(" Adding session_consult to all agents")
    print("=" * 50)
    print()

    success_count = 0
    for agent_dir, role in AGENTS.items():
        print(f"📝 Processing {agent_dir} (role: {role})...")
        if add_session_consult(agent_dir, role):
            success_count += 1
        print()

    print("=" * 50)
    print(f" Completed: {success_count}/{len(AGENTS)} agents updated")
    print("=" * 50)

if __name__ == "__main__":
    main()
