defmodule EchoShared.LLM.Client do
  @moduledoc """
  HTTP client for communicating with local LLM servers (Ollama).

  Provides a simple interface for chat completions and text generation
  using locally-hosted models via Ollama API.

  ## Configuration

  The Ollama endpoint can be configured via environment variable:

      OLLAMA_ENDPOINT=http://localhost:11434

  Or in config:

      config :echo_shared, :ollama_endpoint, "http://localhost:11434"

  ## Usage

      # Simple chat completion
      {:ok, response} = Client.chat("llama3.1", [
        %{role: "user", content: "What is the capital of France?"}
      ])

      # Generate with options
      {:ok, response} = Client.generate("deepseek-coder", "Write a hello world in Elixir", %{
        temperature: 0.7,
        max_tokens: 500
      })
  """

  require Logger

  @default_endpoint "http://localhost:11434"
  @default_timeout 180_000  # 180 seconds (3 minutes) - increased for cold model loading
  @default_temperature 0.7
  @default_max_tokens 2000

  @doc """
  Send a chat completion request to Ollama.

  ## Parameters

  - `model` - The model name (e.g., "llama3.1", "deepseek-coder:33b")
  - `messages` - List of message maps with :role and :content keys
  - `opts` - Optional map with :temperature, :max_tokens, :timeout

  ## Returns

  - `{:ok, response_text}` on success
  - `{:error, reason}` on failure

  ## Example

      messages = [
        %{role: "system", content: "You are a helpful assistant."},
        %{role: "user", content: "Hello!"}
      ]
      {:ok, response} = Client.chat("llama3.1:8b", messages)
  """
  def chat(model, messages, opts \\ %{}) do
    endpoint = get_endpoint()
    url = "#{endpoint}/api/chat"

    payload = %{
      model: model,
      messages: messages,
      stream: false,
      options: build_options(opts)
    }

    Logger.debug("LLM chat request to #{model}: #{length(messages)} messages")

    case post(url, payload, opts) do
      {:ok, %{status: 200, body: body}} ->
        response_text = get_in(body, ["message", "content"]) || ""
        Logger.debug("LLM chat response: #{String.length(response_text)} chars")
        {:ok, response_text}

      {:ok, %{status: status, body: body}} ->
        Logger.error("LLM API error (#{status}): #{inspect(body)}")
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        Logger.error("LLM request failed: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("LLM chat exception: #{inspect(e)}")
      {:error, {:exception, e}}
  end

  @doc """
  Generate text completion from a prompt.

  ## Parameters

  - `model` - The model name (e.g., "codellama", "mistral")
  - `prompt` - Text prompt to complete
  - `opts` - Optional map with :temperature, :max_tokens, :timeout, :system

  ## Returns

  - `{:ok, response_text}` on success
  - `{:error, reason}` on failure

  ## Example

      {:ok, response} = Client.generate(
        "deepseek-coder:6.7b",
        "Write a function to calculate fibonacci",
        %{temperature: 0.3}
      )
  """
  def generate(model, prompt, opts \\ %{}) do
    endpoint = get_endpoint()
    url = "#{endpoint}/api/generate"

    payload = %{
      model: model,
      prompt: prompt,
      stream: false,
      options: build_options(opts)
    }

    # Add system message if provided
    payload = if system = opts[:system] do
      Map.put(payload, :system, system)
    else
      payload
    end

    Logger.debug("LLM generate request to #{model}: #{String.length(prompt)} chars")

    case post(url, payload, opts) do
      {:ok, %{status: 200, body: body}} ->
        response_text = body["response"] || ""
        Logger.debug("LLM generate response: #{String.length(response_text)} chars")
        {:ok, response_text}

      {:ok, %{status: status, body: body}} ->
        Logger.error("LLM API error (#{status}): #{inspect(body)}")
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        Logger.error("LLM request failed: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("LLM generate exception: #{inspect(e)}")
      {:error, {:exception, e}}
  end

  @doc """
  Check if Ollama is available and responding.

  Returns `{:ok, models}` with list of available models, or `{:error, reason}`.
  """
  def health_check do
    endpoint = get_endpoint()
    url = "#{endpoint}/api/tags"

    case Req.get(url, receive_timeout: 5_000) do
      {:ok, %{status: 200, body: body}} ->
        models = get_in(body, ["models"]) || []
        model_names = Enum.map(models, & &1["name"])
        {:ok, model_names}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e ->
      {:error, {:exception, e}}
  end

  @doc """
  Pull a model from Ollama library.

  This is a blocking operation that can take several minutes for large models.

  Returns `:ok` on success or `{:error, reason}` on failure.
  """
  def pull_model(model_name) do
    endpoint = get_endpoint()
    url = "#{endpoint}/api/pull"

    payload = %{name: model_name, stream: false}

    Logger.info("Pulling model #{model_name} from Ollama...")

    case Req.post(url, json: payload, receive_timeout: 600_000) do
      {:ok, %{status: 200}} ->
        Logger.info("Successfully pulled model #{model_name}")
        :ok

      {:ok, %{status: status, body: body}} ->
        Logger.error("Failed to pull model #{model_name}: #{status} - #{inspect(body)}")
        {:error, {:pull_failed, status, body}}

      {:error, reason} ->
        Logger.error("Failed to pull model #{model_name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  ## Private Functions

  defp get_endpoint do
    System.get_env("OLLAMA_ENDPOINT") ||
      Application.get_env(:echo_shared, :ollama_endpoint, @default_endpoint)
  end

  defp build_options(opts) do
    %{
      temperature: opts[:temperature] || @default_temperature,
      num_predict: opts[:max_tokens] || @default_max_tokens
    }
  end

  defp post(url, payload, opts) do
    timeout = opts[:timeout] || @default_timeout

    Req.post(url,
      json: payload,
      receive_timeout: timeout,
      retry: :transient,
      max_retries: 1,  # Reduced from 2 to 1 (total 2 attempts: 180s × 2 = 360s max)
      retry_delay: fn attempt -> :timer.seconds(5 * attempt) end  # Exponential backoff: 5s, 10s, 15s...
    )
  end
end
