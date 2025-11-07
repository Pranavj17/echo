alias EchoShared.{Repo, AgentHealthMonitor, MessageBus}

# Clear old heartbeats
Repo.delete_all(EchoShared.Schemas.AgentStatus)

# Simulate some agents sending heartbeats
IO.puts("Simulating agent heartbeats...")
AgentHealthMonitor.record_heartbeat(:ceo, %{version: "1.0.0", status: "healthy"})
AgentHealthMonitor.record_heartbeat(:cto, %{version: "1.0.0", status: "healthy"})
AgentHealthMonitor.record_heartbeat(:product_manager, %{version: "1.0.0", status: "healthy"})

Process.sleep(100)

# Send some messages
IO.puts("Creating test messages...")
{:ok, _} = MessageBus.publish_message(:ceo, :cto, :request, "Technical Review Needed", %{project: "ECHO"})
{:ok, _} = MessageBus.publish_message(:product_manager, :ceo, :notification, "Q4 Roadmap Ready", %{})

IO.puts("✓ Test data created successfully!")
