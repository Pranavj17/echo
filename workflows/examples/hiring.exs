# Hiring Workflow Example
#
# This workflow demonstrates hierarchical decision-making
# for hiring a new engineer.
#
# Participants: CTO, CHRO, Senior Architect
#
# Decision Pattern: Hierarchical (escalates based on budget)

alias EchoShared.Workflow.Definition

Definition.new(
  "hiring_engineer",
  "Complete hiring workflow for engineering position",
  [:cto, :chro, :senior_architect],
  [
    # Step 1: CTO identifies need and creates requisition
    {:request, :cto, "create_hiring_requisition", %{
      role: "senior_engineer",
      department: "engineering",
      justification: "Team capacity constraint"
    }},

    # Step 2: CHRO reviews against budget and headcount
    {:request, :chro, "review_hiring_request", %{
      check_budget: true,
      check_headcount: true
    }},

    # Step 3: Conditional - escalate to CEO if over budget
    {:conditional,
      fn context -> context[:budget_approved] == false end,
      {:request, :ceo, "approve_hiring_budget", %{urgency: "medium"}},
      {:notify, :chro, "Budget pre-approved for hiring"}
    },

    # Step 4: CHRO approves requisition
    {:request, :chro, "approve_hiring_requisition", %{}},

    # Step 5: CHRO posts job and screens candidates
    {:notify, :chro, "Job posted and candidate screening in progress"},

    # Step 6: Pause for candidate applications (simulated delay)
    {:pause, "Waiting for qualified candidates to apply"},

    # Step 7: Parallel - Technical interviews
    {:parallel, [
      {:request, :cto, "conduct_technical_interview", %{focus: "system_design"}},
      {:request, :senior_architect, "conduct_technical_interview", %{focus: "architecture"}}
    ]},

    # Step 8: Collaborative decision on candidate
    {:request, :chro, "make_offer_decision", %{
      input_from: [:cto, :senior_architect]
    }},

    # Step 9: Record hiring decision
    {:decision, %{
      type: "hiring_approval",
      mode: :hierarchical,
      participants: [:chro, :cto, :senior_architect],
      escalated_to: :ceo
    }}
  ],
  timeout: 1_800_000,  # 30 minutes (excluding pause)
  metadata: %{
    category: "human_resources",
    visibility: "leadership",
    tags: ["hiring", "hierarchical"]
  }
)
