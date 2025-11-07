defmodule EchoShared.MCP.Protocol do
  @moduledoc """
  MCP (Model Context Protocol) JSON-RPC 2.0 implementation.

  Implements the MCP protocol specification version 2024-11-05 for
  communication between ECHO agents and MCP clients (like Claude Desktop).

  ## Protocol Flow

  1. **Client sends request** via stdin (JSON-RPC 2.0)
  2. **Server parses and validates** the request
  3. **Server executes** tool/prompt/resource handler
  4. **Server responds** via stdout (JSON-RPC 2.0)

  ## Supported Methods

  - `initialize` - MCP handshake
  - `tools/list` - List available tools
  - `tools/call` - Execute a tool
  - `prompts/list` - List available prompts
  - `prompts/get` - Get a prompt
  - `resources/list` - List available resources
  - `resources/read` - Read a resource
  - `notifications/*` - Handle notifications (no response)

  ## Message Format

  ### Request
  ```json
  {
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "approve_strategy",
      "arguments": {"proposal": "...", "budget": 100000}
    }
  }
  ```

  ### Response
  ```json
  {
    "jsonrpc": "2.0",
    "id": 1,
    "result": {
      "content": [
        {"type": "text", "text": "Strategy approved"}
      ]
    }
  }
  ```

  ### Error
  ```json
  {
    "jsonrpc": "2.0",
    "id": 1,
    "error": {
      "code": -32601,
      "message": "Method not found"
    }
  }
  ```
  """

  require Logger

  @json_rpc_version "2.0"
  @mcp_version "2024-11-05"

  @type request :: %{
          jsonrpc: String.t(),
          id: integer() | String.t() | nil,
          method: String.t(),
          params: map()
        }

  @type response :: %{
          jsonrpc: String.t(),
          id: integer() | String.t(),
          result: any()
        }

  @type error_response :: %{
          jsonrpc: String.t(),
          id: integer() | String.t() | nil,
          error: %{
            code: integer(),
            message: String.t(),
            data: any()
          }
        }

  @doc """
  Parse a JSON-RPC 2.0 request from stdin line.
  """
  @spec parse_request(String.t()) :: {:ok, request()} | {:error, term()}
  def parse_request(line) do
    case Jason.decode(line) do
      {:ok, request} when is_map(request) ->
        validate_request(request)

      {:error, reason} ->
        {:error, {:parse_error, reason}}
    end
  end

  @doc """
  Create a successful JSON-RPC 2.0 response.
  """
  @spec success_response(integer() | String.t(), any()) :: response()
  def success_response(id, result) do
    %{
      jsonrpc: @json_rpc_version,
      id: id,
      result: result
    }
  end

  @doc """
  Create an error JSON-RPC 2.0 response.
  """
  @spec error_response(integer() | String.t() | nil, integer(), String.t(), any()) ::
          error_response()
  def error_response(id, code, message, data \\ nil) do
    error = %{
      code: code,
      message: message
    }

    error =
      if data do
        Map.put(error, :data, data)
      else
        error
      end

    %{
      jsonrpc: @json_rpc_version,
      id: id,
      error: error
    }
  end

  @doc """
  Encode a response to JSON string for stdout.
  """
  @spec encode_response(response() | error_response()) :: {:ok, String.t()} | {:error, term()}
  def encode_response(response) do
    Jason.encode(response)
  end

  @doc """
  Create MCP initialize response with server capabilities.
  """
  @spec initialize_response(keyword()) :: map()
  def initialize_response(opts \\ []) do
    %{
      protocolVersion: @mcp_version,
      capabilities: %{
        tools: Keyword.get(opts, :tools, %{}),
        prompts: Keyword.get(opts, :prompts, %{}),
        resources: Keyword.get(opts, :resources, %{})
      },
      serverInfo: %{
        name: Keyword.get(opts, :name, "echo-agent"),
        version: Keyword.get(opts, :version, "0.1.0")
      }
    }
  end

  @doc """
  Create tools/list response.
  """
  @spec tools_list_response([map()]) :: map()
  def tools_list_response(tools) do
    %{
      tools: tools
    }
  end

  @doc """
  Create tools/call success response.
  """
  @spec tools_call_response(String.t()) :: map()
  def tools_call_response(text) when is_binary(text) do
    %{
      content: [
        %{type: "text", text: text}
      ]
    }
  end

  def tools_call_response(content) when is_list(content) do
    %{
      content: content
    }
  end

  ## Private Functions

  defp validate_request(request) do
    with :ok <- validate_jsonrpc(request),
         :ok <- validate_method(request) do
      {:ok,
       %{
         jsonrpc: request["jsonrpc"],
         id: request["id"],
         method: request["method"],
         params: request["params"] || %{}
       }}
    end
  end

  defp validate_jsonrpc(%{"jsonrpc" => @json_rpc_version}), do: :ok

  defp validate_jsonrpc(_) do
    {:error, {:invalid_request, "Invalid JSON-RPC version"}}
  end

  defp validate_method(%{"method" => method}) when is_binary(method), do: :ok

  defp validate_method(_) do
    {:error, {:invalid_request, "Missing or invalid method"}}
  end

  @doc """
  Error codes per JSON-RPC 2.0 spec.
  """
  def error_codes do
    %{
      parse_error: -32700,
      invalid_request: -32600,
      method_not_found: -32601,
      invalid_params: -32602,
      internal_error: -32603
    }
  end
end
