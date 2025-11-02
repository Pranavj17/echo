defmodule EchoShared.MCP.Server do
  @moduledoc """
  Base MCP server implementation for ECHO agents.

  This module provides the common server loop and message handling
  that all ECHO agents use. Each agent implements specific callbacks
  to define their tools, prompts, and resources.

  ## Usage

  ```elixir
  defmodule EchoAgents.CEO do
    use EchoShared.MCP.Server

    @impl true
    def agent_info do
      %{
        name: "echo-ceo",
        version: "0.1.0",
        role: :ceo
      }
    end

    @impl true
    def tools do
      [
        %{
          name: "approve_strategy",
          description: "Approve strategic initiative",
          inputSchema: %{
            type: "object",
            properties: %{
              proposal: %{type: "string"},
              budget: %{type: "number"}
            },
            required: ["proposal"]
          }
        }
      ]
    end

    @impl true
    def execute_tool("approve_strategy", args) do
      # Implementation
      {:ok, "Strategy approved"}
    end
  end
  ```

  ## Callbacks

  - `agent_info/0` - Returns agent metadata (name, version, role)
  - `tools/0` - Returns list of MCP tools
  - `execute_tool/2` - Executes a tool by name
  - `prompts/0` (optional) - Returns list of MCP prompts
  - `resources/0` (optional) - Returns list of MCP resources
  """

  alias EchoShared.MCP.Protocol

  @callback agent_info() :: %{name: String.t(), version: String.t(), role: atom()}
  @callback tools() :: [map()]
  @callback execute_tool(name :: String.t(), args :: map()) ::
              {:ok, String.t() | [map()]} | {:error, term()}
  @callback prompts() :: [map()]
  @callback resources() :: [map()]

  defmacro __using__(_opts) do
    quote do
      @behaviour EchoShared.MCP.Server
      require Logger

      # Default implementations
      @impl true
      def prompts, do: []

      @impl true
      def resources, do: []

      defoverridable prompts: 0, resources: 0

      @doc """
      Start the MCP server loop.

      Reads JSON-RPC requests from stdin and writes responses to stdout.
      """
      def start do
        Logger.info("Starting #{agent_info().name} MCP server...")

        # Read stdin line by line
        IO.stream(:stdio, :line)
        |> Stream.filter(&(&1 != "\n"))
        |> Enum.each(&handle_line/1)
      end

      defp handle_line(line) do
        case Protocol.parse_request(line) do
          {:ok, request} ->
            handle_request(request)

          {:error, {:parse_error, reason}} ->
            error_codes = Protocol.error_codes()

            response =
              Protocol.error_response(
                nil,
                error_codes.parse_error,
                "Parse error",
                inspect(reason)
              )

            send_response(response)
        end
      end

      defp handle_request(%{method: "initialize", id: id}) do
        info = agent_info()

        result =
          Protocol.initialize_response(
            name: info.name,
            version: info.version,
            tools: if(Enum.empty?(tools()), do: %{}, else: %{listChanged: false}),
            prompts: if(Enum.empty?(prompts()), do: %{}, else: %{listChanged: false}),
            resources: if(Enum.empty?(resources()), do: %{}, else: %{listChanged: false})
          )

        response = Protocol.success_response(id, result)
        send_response(response)
      end

      defp handle_request(%{method: "tools/list", id: id}) do
        result = Protocol.tools_list_response(tools())
        response = Protocol.success_response(id, result)
        send_response(response)
      end

      defp handle_request(%{method: "tools/call", id: id, params: params}) do
        tool_name = params["name"]
        arguments = params["arguments"] || %{}

        case execute_tool(tool_name, arguments) do
          {:ok, result_text} when is_binary(result_text) ->
            result = Protocol.tools_call_response(result_text)
            response = Protocol.success_response(id, result)
            send_response(response)

          {:ok, content} when is_list(content) ->
            result = Protocol.tools_call_response(content)
            response = Protocol.success_response(id, result)
            send_response(response)

          {:error, reason} ->
            error_codes = Protocol.error_codes()

            response =
              Protocol.error_response(
                id,
                error_codes.internal_error,
                "Tool execution failed",
                inspect(reason)
              )

            send_response(response)
        end
      end

      defp handle_request(%{method: "prompts/list", id: id}) do
        result = %{prompts: prompts()}
        response = Protocol.success_response(id, result)
        send_response(response)
      end

      defp handle_request(%{method: "resources/list", id: id}) do
        result = %{resources: resources()}
        response = Protocol.success_response(id, result)
        send_response(response)
      end

      defp handle_request(%{method: "notifications/" <> _, id: nil}) do
        # Notifications don't require a response
        :ok
      end

      defp handle_request(%{method: method, id: id}) do
        error_codes = Protocol.error_codes()

        response =
          Protocol.error_response(
            id,
            error_codes.method_not_found,
            "Method not found: #{method}"
          )

        send_response(response)
      end

      defp send_response(response) do
        case Protocol.encode_response(response) do
          {:ok, json} ->
            IO.puts(json)

          {:error, reason} ->
            Logger.error("Failed to encode response: #{inspect(reason)}")
        end
      end
    end
  end
end
