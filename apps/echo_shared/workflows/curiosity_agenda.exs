alias EchoShared.Workflow.Definition

Definition.new(
  "curiosity_agenda",
  """
  Company-wide initiative: Explore and implement "How can AI be curious?"

  This workflow demonstrates a complete company agenda where:
  1. CEO sets the strategic vision
  2. Leadership team discusses the concept
  3. Product Manager defines user stories
  4. Senior Architect designs the technical approach
  5. CTO approves the architecture
  6. UI/UX Engineer creates the experience
  7. Senior Developer implements the feature
  8. Test Lead validates the implementation
  9. CHRO tracks team learning and growth

  All agents work towards a common goal with authentic discussion and planning.
  """,
  [:ceo, :cto, :chro, :product_manager, :senior_architect, :uiux_engineer, :senior_developer, :test_lead, :operations_head],
  [
    # ============================================================================
    # PHASE 1: STRATEGIC VISION - CEO sets company agenda
    # ============================================================================
    {:request, :ceo, "set_company_vision", %{
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
    }},

    # ============================================================================
    # PHASE 2: LEADERSHIP DISCUSSION - All C-level discuss the vision
    # ============================================================================
    {:parallel, [
      {:request, :cto, "evaluate_technical_feasibility", %{
        agenda: "AI Curiosity Implementation",
        questions_to_explore: [
          "What defines curiosity in computational terms?",
          "Can we measure information gaps that drive curiosity?",
          "How do we encode intrinsic motivation?",
          "What's the difference between random exploration and genuine curiosity?"
        ],
        technical_concerns: [
          "Computational cost of curiosity mechanisms",
          "Preventing curiosity from becoming chaotic exploration",
          "Safety boundaries for curious AI"
        ]
      }},

      {:request, :chro, "assess_team_capabilities", %{
        agenda: "AI Curiosity Research",
        required_skills: [
          "Reinforcement learning expertise",
          "Information theory knowledge",
          "Cognitive science background",
          "ML research experience"
        ],
        team_development_needs: [
          "Training on curiosity-driven learning algorithms",
          "Workshop on intrinsic motivation in AI",
          "Reading group on human curiosity research"
        ]
      }},

      {:request, :operations_head, "plan_resource_allocation", %{
        agenda: "AI Curiosity Initiative",
        required_resources: [
          "GPU compute for experimentation",
          "Research literature access",
          "Conference attendance budget",
          "Prototype development environment"
        ],
        timeline_breakdown: %{
          research_phase: "3 weeks",
          design_phase: "2 weeks",
          prototype_phase: "4 weeks",
          testing_phase: "2 weeks",
          refinement_phase: "1 week"
        }
      }}
    ]},

    # ============================================================================
    # PHASE 3: PRODUCT VISION - PM translates vision to user stories
    # ============================================================================
    {:request, :product_manager, "create_feature_requirement", %{
      feature_name: "Curiosity Engine",
      description: """
      A curiosity-driven learning system that enables AI agents to:
      - Identify gaps in their knowledge autonomously
      - Ask clarifying questions when context is missing
      - Explore new domains without explicit instruction
      - Prioritize learning based on information value
      """,
      user_stories: [
        "As an AI agent, I want to detect when I don't understand something so that I can ask for clarification",
        "As an AI agent, I want to explore related topics when I learn something new so that I build comprehensive knowledge",
        "As an AI agent, I want to prioritize what to learn next based on how useful it will be",
        "As a developer, I want to see what my AI agent is curious about so that I can understand its learning process"
      ],
      acceptance_criteria: [
        "Agent generates questions without prompting",
        "Agent explores beyond immediate task scope",
        "Agent maintains conversation logs showing curiosity",
        "Agent can explain why it's curious about something"
      ],
      priority: "high",
      estimated_effort: "8 weeks"
    }},

    # ============================================================================
    # PHASE 4: TECHNICAL DISCUSSION - Architect designs the system
    # ============================================================================
    {:request, :senior_architect, "design_technical_architecture", %{
      feature_name: "Curiosity Engine",
      requirements: "AI system that exhibits curiosity through question generation, exploration, and knowledge-seeking behavior",
      design_considerations: [
        "How to represent knowledge gaps computationally",
        "How to score information value",
        "How to balance exploration vs exploitation",
        "How to generate meaningful questions"
      ],
      proposed_components: [
        %{
          name: "Knowledge Graph Tracker",
          purpose: "Maps what agent knows and identifies gaps",
          technology: "Graph database with uncertainty metrics"
        },
        %{
          name: "Question Generator",
          purpose: "Generates questions about knowledge gaps",
          technology: "LLM with question-generation prompts"
        },
        %{
          name: "Curiosity Scorer",
          purpose: "Prioritizes what to explore next",
          technology: "Information theory metrics (entropy, mutual information)"
        },
        %{
          name: "Exploration Engine",
          purpose: "Actively seeks information to fill gaps",
          technology: "Reinforcement learning with intrinsic rewards"
        }
      ],
      architecture_approach: "Event-driven system where knowledge gaps trigger curiosity behaviors"
    }},

    # ============================================================================
    # PHASE 5: TECHNICAL APPROVAL - CTO reviews and approves
    # ============================================================================
    {:conditional,
      fn context -> context[:budget_allocation] >= 200_000 end,
      {:request, :cto, "approve_technical_proposal", %{
        proposal: "Curiosity Engine Architecture",
        budget_required: 350_000,
        timeline: "8 weeks",
        technical_complexity: "high",
        innovation_level: "cutting-edge",
        risks: [
          "Curiosity might generate too many questions (overwhelming)",
          "Curiosity might explore unsafe topics",
          "Measuring genuine curiosity vs random behavior is subjective"
        ],
        mitigation_strategies: [
          "Rate limiting on question generation",
          "Safety filters on exploration domains",
          "Multiple curiosity metrics (diversity, relevance, depth)"
        ]
      }},
      {:notify, :product_manager, "Budget too low for curiosity project - needs CEO approval"}
    },

    # ============================================================================
    # PHASE 6: EXPERIENCE DESIGN - UX creates the interaction model
    # ============================================================================
    {:request, :uiux_engineer, "design_user_experience", %{
      feature_name: "Curiosity Engine",
      user_goals: [
        "See what the AI is curious about",
        "Answer AI's questions",
        "Encourage productive curiosity",
        "Understand AI's learning journey"
      ],
      design_concepts: [
        %{
          element: "Curiosity Dashboard",
          description: "Visual map of AI's knowledge gaps and questions",
          interactions: ["Click on gap to see questions", "Answer questions inline", "Mark questions as explored"]
        },
        %{
          element: "Question Stream",
          description: "Real-time feed of AI-generated questions",
          interactions: ["Upvote interesting questions", "Provide answers", "Suggest exploration paths"]
        },
        %{
          element: "Knowledge Graph Visualization",
          description: "Interactive graph showing what AI knows and is curious about",
          interactions: ["Zoom into topic", "See confidence levels", "Highlight gaps"]
        }
      ],
      accessibility_requirements: [
        "Screen reader support for knowledge graphs",
        "Keyboard navigation for question stream",
        "High contrast mode for confidence visualization"
      ]
    }},

    # ============================================================================
    # PHASE 7: PARALLEL IMPLEMENTATION - Dev builds, Test plans, CHRO tracks
    # ============================================================================
    {:parallel, [
      {:request, :senior_developer, "implement_feature", %{
        feature_name: "Curiosity Engine",
        technical_spec: "Event-driven curiosity system with knowledge graph, question generator, and exploration engine",
        implementation_phases: [
          %{
            phase: 1,
            name: "Knowledge Graph Foundation",
            tasks: [
              "Set up graph database",
              "Create knowledge node schema",
              "Implement uncertainty tracking",
              "Build gap detection algorithm"
            ],
            duration: "2 weeks"
          },
          %{
            phase: 2,
            name: "Question Generation",
            tasks: [
              "Integrate LLM for question generation",
              "Create question templates",
              "Implement relevance scoring",
              "Add rate limiting"
            ],
            duration: "2 weeks"
          },
          %{
            phase: 3,
            name: "Curiosity Scoring",
            tasks: [
              "Implement entropy calculations",
              "Build information value metrics",
              "Create exploration prioritization",
              "Add safety filters"
            ],
            duration: "2 weeks"
          },
          %{
            phase: 4,
            name: "Integration & Polish",
            tasks: [
              "Connect all components",
              "Add monitoring and logging",
              "Performance optimization",
              "Documentation"
            ],
            duration: "2 weeks"
          }
        ],
        programming_languages: ["Python", "Elixir", "GraphQL"],
        frameworks: ["LangChain", "Neo4j", "Phoenix"]
      }},

      {:request, :test_lead, "create_test_strategy", %{
        feature_name: "Curiosity Engine",
        testing_approach: "Behavior-driven testing with curiosity metrics",
        test_categories: [
          %{
            category: "Unit Tests",
            focus: "Individual curiosity components",
            tests: [
              "Knowledge gap detection accuracy",
              "Question generation quality",
              "Information value calculations",
              "Safety filter effectiveness"
            ]
          },
          %{
            category: "Integration Tests",
            focus: "Component interactions",
            tests: [
              "Gap triggers question generation",
              "Questions lead to exploration",
              "Exploration updates knowledge graph",
              "Learning reduces curiosity about filled gaps"
            ]
          },
          %{
            category: "Behavioral Tests",
            focus: "Curiosity behaviors",
            tests: [
              "Agent asks questions without prompting",
              "Agent explores related topics",
              "Agent prioritizes important gaps",
              "Agent explains its curiosity"
            ]
          },
          %{
            category: "Safety Tests",
            focus: "Curiosity boundaries",
            tests: [
              "Rate limiting prevents question spam",
              "Safety filters block harmful exploration",
              "Agent respects privacy boundaries",
              "Curiosity doesn't derail primary tasks"
            ]
          }
        ],
        success_metrics: [
          "95% of generated questions are coherent",
          "80% of questions are relevant to knowledge gaps",
          "Agent explores 5+ related topics per session",
          "Zero safety violations in 1000 explorations"
        ]
      }},

      {:request, :chro, "track_team_learning", %{
        initiative: "AI Curiosity Project",
        learning_objectives: [
          "Team members understand curiosity mechanisms",
          "Team can explain intrinsic motivation in AI",
          "Team gains research skills in novel AI capabilities"
        ],
        knowledge_sharing_activities: [
          "Weekly curiosity research presentations",
          "Paper reading group on AI exploration",
          "Demo sessions showing curiosity behaviors",
          "Retrospective on what we learned building this"
        ],
        skill_development_tracking: [
          "Before/after assessments on AI curiosity concepts",
          "Documentation of insights discovered",
          "Team members publishing blog posts on learnings"
        ]
      }}
    ]},

    # ============================================================================
    # PHASE 8: VALIDATION & REVIEW - Test lead validates implementation
    # ============================================================================
    {:request, :test_lead, "validate_implementation", %{
      feature_name: "Curiosity Engine",
      validation_criteria: [
        "All unit tests passing",
        "Integration tests show proper curiosity flow",
        "Behavioral tests demonstrate authentic curiosity",
        "Safety tests confirm boundaries are respected"
      ],
      test_results_location: "/results/curiosity_engine_tests.json",
      performance_benchmarks: [
        "Question generation < 2 seconds",
        "Knowledge gap detection < 500ms",
        "Curiosity scoring < 100ms",
        "Graph queries < 50ms"
      ]
    }},

    # ============================================================================
    # PHASE 9: DEPLOYMENT APPROVAL - CEO reviews final implementation
    # ============================================================================
    {:request, :ceo, "approve_deployment", %{
      feature_name: "Curiosity Engine",
      deployment_scope: "Production rollout to all AI agents",
      expected_impact: [
        "AI agents become self-directed learners",
        "Reduced need for explicit training data",
        "Agents discover novel solutions through exploration",
        "Improved agent engagement and adaptability"
      ],
      deployment_plan: %{
        phase_1: "Deploy to 10% of agents (monitoring)",
        phase_2: "Expand to 50% if metrics are positive",
        phase_3: "Full rollout after 2 weeks of validation"
      },
      success_metrics_review: "Check if agents are asking meaningful questions and exploring productively",
      final_budget_used: 320_000,
      final_timeline: "8 weeks (on schedule)"
    }},

    # ============================================================================
    # PHASE 10: RETROSPECTIVE - CHRO leads team reflection
    # ============================================================================
    {:request, :chro, "conduct_retrospective", %{
      initiative: "AI Curiosity Project - Complete",
      retrospective_questions: [
        "What did we learn about building curiosity into AI?",
        "What surprised us during implementation?",
        "What would we do differently next time?",
        "How has this changed our thinking about AI capabilities?",
        "What new questions do WE now have about AI curiosity?"
      ],
      team_reflections_to_capture: [
        "Technical insights discovered",
        "Design patterns that emerged",
        "Collaboration approaches that worked well",
        "Skills the team developed"
      ],
      knowledge_artifacts_to_create: [
        "Technical blog post: 'How We Built a Curious AI'",
        "Research paper: 'Computational Models of AI Curiosity'",
        "Internal playbook: 'Designing Intrinsic Motivation Systems'",
        "Conference talk proposal: 'Curiosity-Driven AI at ECHO'"
      ]
    }}
  ],
  [
    timeout: 7_200_000,  # 2 hour timeout
    metadata: %{
      workflow_type: "company_initiative",
      initiative_theme: "curiosity",
      question_explored: "How can AI be curious?",
      total_agents: 9,
      phases: 10,
      expected_duration: "8 weeks",
      collaboration_model: "hierarchical with cross-functional discussion"
    }
  ]
)
