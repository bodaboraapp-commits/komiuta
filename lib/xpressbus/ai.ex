defmodule Xpressbus.AI do
  @moduledoc """
  Thin, provider-agnostic client for the Chyllz AI assistant.

  The app talks to any **OpenAI-compatible** chat-completions endpoint, which
  covers OpenAI, Azure OpenAI gateways, OpenRouter, Groq, Together, vLLM and
  most other hosted inference providers. Configuration is resolved in this
  order:

    1. the active **Chyllz AI** integration row saved in the admin
       **Settings → Integrations** page (`provider: "ai"`), if it has a key;
    2. `config :xpressbus, :ai` / runtime environment variables
       (`AI_API_KEY`, `AI_BASE_URL`, ...).

  An admin-disabled integration forces local mode even when an environment key
  exists. This lets operations rotate a key from the admin page without a
  redeploy, while still allowing environment-only deployments.

  The client is deliberately small and defensive:

    * it never raises — every failure is returned as `{:error, reason}` so the
      assistant can fall back to its catalogue-grounded local guide;
    * it never logs or returns the API key;
    * it has a hard receive timeout and no retries, so a slow provider cannot
      hold a LiveView process hostage;
    * it only builds the request; prompt rules and safety instructions live in
      `Xpressbus.TravelAssistant`.

  When no API key is configured `configured?/0` returns `false` and the
  assistant runs entirely on the local guide, so the Chyllz pages work out of
  the box in development, tests and preview environments.
  """

  @defaults %{
    enabled: true,
    provider: "openai",
    api_key: nil,
    base_url: "https://api.openai.com/v1",
    model: "gpt-4o-mini",
    vision_model: "gpt-4o-mini",
    temperature: 0.4,
    max_tokens: 700,
    timeout: 20_000
  }

  @type message :: %{required(String.t()) => String.t() | [map()]}

  alias Xpressbus.Integrations

  @config_keys [:api_key, :base_url, :model, :vision_model, :timeout]

  @doc """
  Returns the effective AI configuration, merged over the compile-time defaults.

  An active admin integration overrides the environment. A disabled integration
  forces `enabled: false`. An active integration without a key falls back to the
  environment/default configuration, so a half-configured admin tab cannot
  silently break a working environment-key deployment.
  """
  def config do
    base =
      @defaults
      |> Map.merge(Application.get_env(:xpressbus, :ai, %{}))

    case integration() do
      %{source: :disabled} ->
        Map.put(base, :enabled, false)

      %{source: :integration} = integration ->
        overrides =
          Enum.reduce(@config_keys, %{}, fn key, acc ->
            case Map.get(integration, key) do
              nil -> acc
              value -> Map.put(acc, key, value)
            end
          end)

        base
        |> Map.merge(overrides)
        |> Map.put(:enabled, true)

      _other ->
        base
    end
  end

  @doc """
  Admin-facing status for the Chyllz AI integration.

  Deliberately excludes the API key: the admin page only needs to know whether a
  key is stored, which source is active and what model/URL the assistant will
  use. The same map is assigned in the Integration LiveView after every save,
  toggle or clear.
  """
  def provider_status do
    active_integration = integration()
    config = config()
    env = Application.get_env(:xpressbus, :ai, %{})
    env_key = present?(Map.get(env, :api_key))

    source =
      cond do
        match?(%{source: :disabled}, active_integration) -> :disabled
        match?(%{source: :integration}, active_integration) -> :integration
        env_key -> :environment
        match?(%{source: :missing_key}, active_integration) -> :missing_key
        true -> :none
      end

    %{
      configured: configured?(config),
      source: source,
      model: config.model,
      vision_model: config.vision_model,
      base_url: config.base_url,
      has_integration: not is_nil(active_integration),
      integration_active: active_integration && Map.get(active_integration, :active),
      has_integration_key: match?(%{source: :integration}, active_integration),
      integration_missing_key: match?(%{source: :missing_key}, active_integration),
      has_env_key: env_key
    }
  end

  @doc """
  True when a usable API key is configured and AI use has not been disabled.
  """
  def configured?(config \\ config()) do
    config = Map.merge(@defaults, config)

    config.enabled != false and present?(config.api_key) and
      is_binary(config.base_url) and String.trim(config.base_url) != ""
  end

  @doc """
  Sends a chat-completion request and returns the assistant text.

  `messages` must already be in OpenAI wire format: a list of maps with
  `"role"` and `"content"` keys. Content may be a string or a list of content
  parts (used for images).

  Options (all optional):

    * `:model` — override the configured model
    * `:api_key`, `:base_url`, `:timeout`, `:max_tokens`, `:temperature`
    * `:req_options` — extra `Req` options, used by tests to inject a stub plug
  """
  def chat(messages, opts \\ []) when is_list(messages) do
    config = Map.merge(@defaults, config())

    api_key = Keyword.get(opts, :api_key, config.api_key)
    base_url = Keyword.get(opts, :base_url, config.base_url)
    model = Keyword.get(opts, :model, config.model)

    enabled? = Keyword.get(opts, :enabled, config.enabled)

    cond do
      enabled? == false or is_nil(api_key) or String.trim(to_string(api_key)) == "" ->
        {:error, :not_configured}

      not is_binary(base_url) or String.trim(base_url) == "" ->
        {:error, :not_configured}

      true ->
        request(config, api_key, base_url, model, messages, opts)
    end
  end

  @doc """
  Builds a vision message (text + image) compatible with OpenAI-style APIs.
  """
  def image_message(text, data_url) do
    %{
      "role" => "user",
      "content" => [
        %{"type" => "text", "text" => text},
        %{"type" => "image_url", "image_url" => %{"url" => data_url, "detail" => "auto"}}
      ]
    }
  end

  # The database lookup is intentionally defensive: AI status is also read from
  # tests/health checks where the integration table may not be available yet.
  # A database hiccup must never make the public assistant page fail.
  defp integration do
    Integrations.ai_integration()
  rescue
    _exception -> nil
  end

  defp present?(value) do
    is_binary(value) and String.trim(value) != ""
  end

  defp request(config, api_key, base_url, model, messages, opts) do
    url = String.trim_trailing(base_url, "/") <> "/chat/completions"

    body = %{
      "model" => model,
      "messages" => messages,
      "temperature" => Keyword.get(opts, :temperature, config.temperature),
      "max_tokens" => Keyword.get(opts, :max_tokens, config.max_tokens)
    }

    request_options =
      [
        headers: [
          {"authorization", "Bearer " <> api_key},
          {"content-type", "application/json"}
        ],
        json: body,
        receive_timeout: Keyword.get(opts, :timeout, config.timeout),
        connect_options: [timeout: 5_000],
        retry: false
      ]
      |> Keyword.merge(Map.get(config, :req_options, []))
      |> Keyword.merge(Keyword.get(opts, :req_options, []))

    case Req.post(url, request_options) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        case extract_text(response_body) do
          {:ok, text} -> {:ok, text}
          :error -> {:error, :empty_response}
        end

      {:ok, %Req.Response{status: status, body: response_body}} ->
        {:error, {:http_status, status, summarize(response_body)}}

      {:error, exception} ->
        {:error, {:request_failed, exception}}
    end
  rescue
    exception ->
      {:error, {:client_failed, exception}}
  end

  defp extract_text(%{"choices" => [%{"message" => %{"content" => content}} | _]}) do
    normalize_content(content)
  end

  defp extract_text(_body), do: :error

  defp normalize_content(content) when is_binary(content) do
    case String.trim(content) do
      "" -> :error
      text -> {:ok, text}
    end
  end

  defp normalize_content(content) when is_list(content) do
    text =
      content
      |> Enum.flat_map(fn
        %{"text" => text} when is_binary(text) -> [text]
        _other -> []
      end)
      |> Enum.join("\n")
      |> String.trim()

    if text == "", do: :error, else: {:ok, text}
  end

  defp normalize_content(_content), do: :error

  # Only a short, non-sensitive summary of an error body is ever kept.
  defp summarize(body) when is_binary(body), do: String.slice(body, 0, 300)

  defp summarize(body) do
    body
    |> inspect(limit: 8, printable_limit: 300)
    |> String.slice(0, 300)
  end
end
