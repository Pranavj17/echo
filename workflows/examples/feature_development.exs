# Feature Development Workflow Example
#
# This workflow demonstrates multi-agent collaboration for developing
# a new product feature from concept to release.
#
# Participants: Product Manager, Senior Architect, UI/UX Engineer,
#               Senior Developer, Test Lead
#
# Decision Pattern: Collaborative + Autonomous steps

alias EchoShared.Workflow.Definition

Definition.new(
  "feature_development",
  "Complete workflow for developing and releasing a new feature",
  [:product_manager, :senior_architect, :uiux_engineer, :senior_developer, :test_lead],
  [
    # Step 1: Product Manager creates feature requirement
    {:request, :product_manager, "create_feature_requirement", %{
      description: "User-facing feature specification",
      priority: "high"
    }},

    # Step 2: Senior Architect reviews technical feasibility
    {:request, :senior_architect, "review_technical_feasibility", %{
      aspects: ["scalability", "performance", "security"]
    }},

    # Step 3: Conditional - if complex, get CTO approval
    {:conditional,
      fn context -> context[:complexity] == "high" end,
      {:request, :cto, "approve_technical_approach", %{}},
      {:notify, :product_manager, "Technical approach approved by architect"}
    },

    # Step 4: UI/UX Engineer designs interface
    {:request, :uiux_engineer, "design_user_interface", %{
      design_system: "current",
      accessibility: "wcag_aa"
    }},

    # Step 5: Product Manager approves design
    {:request, :product_manager, "approve_design", %{}},

    # Step 6: Parallel - Development and test planning
    {:parallel, [
      {:request, :senior_developer, "implement_feature", %{}},
      {:request, :test_lead, "create_test_plan", %{}}
    ]},

    # Step 7: Test Lead validates quality
    {:request, :test_lead, "validate_feature_quality", %{
      criteria: ["functionality", "performance", "security"]
    }},

    # Step 8: Conditional - if quality issues, return to dev
    {:conditional,
      fn context -> context[:quality_gate] == "pass" end,
      {:request, :product_manager, "approve_release", %{}},
      {:request, :senior_developer, "fix_quality_issues", %{}}
    },

    # Step 9: Record decision
    {:decision, %{
      type: "feature_release",
      mode: :collaborative,
      participants: [:product_manager, :senior_architect, :test_lead]
    }}
  ],
  timeout: 7_200_000,  # 2 hours
  metadata: %{
    category: "product_development",
    visibility: "team",
    tags: ["feature", "collaborative"]
  }
)
