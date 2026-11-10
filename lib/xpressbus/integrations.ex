defmodule Xpressbus.Integrations do
  @moduledoc """
  The Integrations context.
  """

  import Ecto.Query, warn: false
  alias Xpressbus.Repo
  alias Xpressbus.Integrations.PaymentConfig

  @doc """
  Gets the M-PESA configuration.
  """
  def get_mpesa_config do
    Repo.get_by(PaymentConfig, provider: "mpesa")
  end

  @doc """
  Upserts the M-PESA configuration.
  """
  def upsert_mpesa_config(attrs) do
    case get_mpesa_config() do
      nil ->
        %PaymentConfig{}
        |> PaymentConfig.changeset(Map.put(attrs, :provider, "mpesa"))
        |> Repo.insert()

      config ->
        config
        |> PaymentConfig.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Returns the list of integrations.
  """
  def list_integrations do
    Repo.all(PaymentConfig)
  end

  @doc """
  Gets a single payment_config.
  """
  def get_payment_config!(id), do: Repo.get!(PaymentConfig, id)

  @doc """
  Gets a payment config by provider name.
  """
  def get_config_by_provider(provider) do
    Repo.get_by(PaymentConfig, provider: provider)
  end

  @login_methods ~w(email sms both)

  @doc """
  The traveller login method selected on the admin Integration page.

  `email` is the safe default (email OTP only). `sms` uses Firebase SMS OTP and
  `both` shows both options. Falls back to `email` when nothing is configured.
  """
  def login_method do
    case get_config_by_provider("user_login") do
      %{active: true, config: config} when is_map(config) ->
        method = config["method"]
        if method in @login_methods, do: method, else: "email"

      _ ->
        "email"
    end
  end

  def login_methods, do: @login_methods

  @doc """
  Returns the saved Google Maps Platform configuration.

  Two credentials are kept deliberately separate:

    * `:browser_key` — referrer-restricted, for browser map views;
    * `:server_key` — unrestricted or IP-restricted, for server-side Places,
      Geocoding and Static Maps requests.

  The legacy single `api_key` is only used as a server-key fallback for
  installations that have not run the split-keys migration yet; the browser key
  must always be a separate referrer-restricted credential.
  """
  def google_maps_config do
    case get_config_by_provider("google_maps") do
      %{active: true, config: config} when is_map(config) ->
        %{
          browser_key: trimmed(config["browser_key"]),
          server_key: trimmed(config["server_key"]) || trimmed(config["api_key"])
        }

      _ ->
        %{browser_key: nil, server_key: nil}
    end
  end

  @doc "The referrer-restricted browser key, or nil."
  def google_maps_browser_key, do: google_maps_config().browser_key

  @doc "The unrestricted/IP-restricted server key, or nil."
  def google_maps_server_key, do: google_maps_config().server_key

  @doc "Backwards-compatible alias for the server key."
  def google_maps_api_key, do: google_maps_server_key()

  @doc "True when both the browser and server keys are configured."
  def google_maps_configured? do
    config = google_maps_config()
    not is_nil(config.browser_key) and not is_nil(config.server_key)
  end

  @ai_default_base_url "https://api.openai.com/v1"
  @ai_default_model "gpt-4o-mini"
  @ai_fields ~w(api_key base_url model vision_model timeout)

  @doc """
  Returns the Chyllz AI provider saved on the admin Integration page.

  The result is intentionally small and stable:

    * `:source` is `:integration` when an active row has an API key,
      `:missing_key` when the row is active but has no key, `:disabled` when
      the admin turned the integration off, and `nil` when no row exists;
    * `:api_key` is only present for an active, configured row;
    * the remaining values are normalised strings/integers for the AI client.

  The API key is never included in the admin-facing status helper
  (`Xpressbus.AI.provider_status/0`); only this internal function returns it.
  """
  def ai_integration do
    case get_config_by_provider("ai") do
      nil ->
        nil

      %{active: false} ->
        %{source: :disabled, active: false}

      %{active: true, config: config} when is_map(config) ->
        key = trimmed(config["api_key"])

        integration = %{
          source: if(key, do: :integration, else: :missing_key),
          active: true,
          base_url: trimmed(config["base_url"]) || @ai_default_base_url,
          model: trimmed(config["model"]) || @ai_default_model,
          vision_model:
            trimmed(config["vision_model"]) || trimmed(config["model"]) || @ai_default_model,
          timeout: ai_timeout(config["timeout"])
        }

        if key, do: Map.put(integration, :api_key, key), else: integration

      %{active: true} ->
        %{
          source: :missing_key,
          active: true,
          base_url: @ai_default_base_url,
          model: @ai_default_model,
          vision_model: @ai_default_model,
          timeout: nil
        }
    end
  end

  @doc "The whitelisted fields accepted from the Chyllz AI admin form."
  def ai_fields, do: @ai_fields

  defp trimmed(value) do
    case value do
      nil ->
        nil

      value ->
        value = value |> to_string() |> String.trim()
        if value == "", do: nil, else: value
    end
  end

  defp ai_timeout(value) do
    case value do
      value when is_integer(value) and value >= 1_000 and value <= 60_000 ->
        value

      value when is_binary(value) ->
        case Integer.parse(String.trim(value)) do
          {timeout, ""} when timeout >= 1_000 and timeout <= 60_000 -> timeout
          _other -> nil
        end

      _other ->
        nil
    end
  end

  @doc """
  Upserts a payment config by provider.
  Expects attrs to be a map with :active and :config (the config map).
  """
  def upsert_config_by_provider(provider, attrs) do
    case get_config_by_provider(provider) do
      nil ->
        %PaymentConfig{}
        |> PaymentConfig.changeset(Map.put(attrs, :provider, provider))
        |> Repo.insert()

      existing ->
        # Merge the config map if it's passed as a map
        new_config_data = Map.get(attrs, :config, %{})
        current_config = existing.config || %{}
        merged_config = Map.merge(current_config, new_config_data)

        updated_attrs = Map.put(attrs, :config, merged_config)

        existing
        |> PaymentConfig.changeset(updated_attrs)
        |> Repo.update()
    end
  end

  def create_payment_config(attrs \\ %{}) do
    %PaymentConfig{}
    |> PaymentConfig.changeset(attrs)
    |> Repo.insert()
  end

  def update_payment_config(%PaymentConfig{} = payment_config, attrs) do
    payment_config
    |> PaymentConfig.changeset(attrs)
    |> Repo.update()
  end

  def delete_payment_config(%PaymentConfig{} = payment_config) do
    Repo.delete(payment_config)
  end

  def change_payment_config(%PaymentConfig{} = payment_config, attrs \\ %{}) do
    PaymentConfig.changeset(payment_config, attrs)
  end
end
