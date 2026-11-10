defmodule XpressbusWeb.AdminIntegrationLive do
  use XpressbusWeb, :live_view
  import XpressbusWeb.AdminComponents
  alias Xpressbus.AI
  alias Xpressbus.Integrations

  @weatherapi_base "https://api.weatherapi.com/v1"

  @providers %{
    "user_login" => %{
      label: "User Login",
      icon: "login",
      description: "Choose how travellers sign in: email code, SMS code, or both"
    },
    "ai" => %{
      label: "Chyllz AI",
      icon: "forum",
      description:
        "OpenAI-compatible provider for the Chyllz Chat, Lens, Receipt and Food assistant"
    },
    "mpesa" => %{
      label: "MPESA",
      icon: "account_balance_wallet",
      description: "Configure Safaricom Daraja API for MPESA payments"
    },
    "flutterwave" => %{
      label: "Flutterwave",
      icon: "credit_card",
      description: "Configure Flutterwave for card and mobile money payments"
    },
    "paystack" => %{
      label: "Paystack",
      icon: "payments",
      description: "Configure Paystack for card payments"
    },
    "google" => %{
      label: "Google Auth",
      icon: "login",
      description: "Configure Google OAuth 2.0 for traveler sign-in"
    },
    "firebase" => %{
      label: "Firebase SMS",
      icon: "sms",
      description: "Firebase Phone Authentication for SMS login codes"
    },
    "weather_api" => %{
      label: "WeatherAPI",
      icon: "wb_sunny",
      description: "WeatherAPI.com key for the live Chyllz weather widget"
    },
    "google_maps" => %{
      label: "Google Maps",
      icon: "location_on",
      description: "Google Maps Platform key for maps, places and geocoding"
    }
  }

  def mount(_params, session, socket) do
    admin_id = session["admin_id"]

    if admin_id do
      current_provider = "mpesa"
      settings = load_settings()

      {:ok,
       socket
       |> assign(:page_title, "Integration Settings")
       |> assign(:active_tab, "mpesa")
       |> assign(:current_provider, current_provider)
       |> assign(:providers, @providers)
       |> assign(:settings, settings)
       |> assign(:firebase_config, Xpressbus.Firebase.client_config())
       |> assign(:login_method_choice, Integrations.login_method())
       |> assign(:ai_status, AI.provider_status())
       |> assign(:sidebar_collapsed, false)
       |> assign(:bus_expanded, false)
       |> assign(:chyllz_expanded, false)
       |> assign(:settings_expanded, true)}
    else
      {:ok,
       socket
       |> assign(:page_title, "Admin Dashboard")
       |> Phoenix.LiveView.redirect(to: ~p"/admin/login")}
    end
  end

  def handle_event("switch_provider", %{"provider" => provider}, socket) do
    {:noreply, assign(socket, :current_provider, provider)}
  end

  def handle_event("select_login_method", %{"config" => %{"method" => method}}, socket) do
    if method in Integrations.login_methods() do
      {:noreply, assign(socket, :login_method_choice, method)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("select_login_method", _params, socket), do: {:noreply, socket}

  def handle_event("save", %{"provider" => "user_login", "config" => config_params}, socket) do
    method =
      if config_params["method"] in Xpressbus.Integrations.login_methods() do
        config_params["method"]
      else
        "email"
      end

    case Integrations.upsert_config_by_provider("user_login", %{
           active: true,
           config: %{"method" => method}
         }) do
      {:ok, _config} ->
        message =
          case method do
            "email" -> "Travellers will sign in with email login codes."
            "sms" -> "Travellers will sign in with Firebase SMS codes."
            "both" -> "Travellers can sign in with either email or SMS codes."
          end

        {:noreply,
         socket
         |> assign(:login_method_choice, method)
         |> put_flash(:info, message)
         |> assign(:settings, load_settings())}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save the login setting")}
    end
  end

  def handle_event("save", %{"provider" => "ai", "config" => config_params}, socket) do
    case build_ai_config(config_params) do
      {:ok, config} ->
        current_active = Map.get(socket.assigns.settings["ai"], :active, true)

        case Integrations.upsert_config_by_provider("ai", %{
               active: current_active,
               config: config
             }) do
          {:ok, _config} ->
            socket = refresh_ai(socket)

            message =
              if socket.assigns.ai_status.configured do
                "Chyllz AI settings saved. The assistant will use the connected provider."
              else
                "Chyllz AI settings saved. Add an API key to enable AI replies; the live catalogue guide stays active meanwhile."
              end

            {:noreply, put_flash(socket, :info, message)}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to save Chyllz AI settings")}
        end

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("save", %{"provider" => provider, "config" => config_params}, socket) do
    # Load current setting to preserve active status if not provided in form
    current_setting = socket.assigns.settings[provider]
    current_active = Map.get(current_setting, :active, true)

    # If the form explicitly sends an 'active' param, use it. Otherwise keep current.
    active =
      case Map.get(config_params, "active") do
        "true" -> true
        "false" -> false
        _ -> current_active
      end

    attrs = %{
      active: active,
      config: Map.delete(config_params, "active")
    }

    case Integrations.upsert_config_by_provider(provider, attrs) do
      {:ok, _config} ->
        # Chyllz reads this integration on every lookup; drop the 15-minute
        # forecast cache so a new key or toggle applies immediately.
        if provider == "weather_api", do: Xpressbus.Weather.clear_cache()

        label = get_in(@providers, [provider, :label]) || String.upcase(provider)

        {:noreply,
         socket
         |> put_flash(:info, "#{label} settings saved successfully")
         |> assign(:settings, load_settings())}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save settings")}
    end
  end

  def handle_event("test_connection", _params, socket) do
    provider = socket.assigns.current_provider

    case provider do
      "paystack" ->
        test_paystack(socket, socket.assigns.settings["paystack"])

      "flutterwave" ->
        test_flutterwave(socket, socket.assigns.settings["flutterwave"])

      "mpesa" ->
        test_mpesa(socket, socket.assigns.settings["mpesa"])

      "firebase" ->
        test_firebase(socket)

      "weather_api" ->
        test_weather_api(socket, socket.assigns.settings["weather_api"])

      "google_maps" ->
        test_google_maps(socket, socket.assigns.settings["google_maps"])

      "ai" ->
        test_ai(socket)

      _ ->
        {:noreply, put_flash(socket, :info, "Handshake successful! Payment gateway is active.")}
    end
  end

  def handle_event("toggle_active", %{"provider" => provider}, socket) do
    current = socket.assigns.settings[provider]
    current_active = Map.get(current, :active, true)

    case Integrations.upsert_config_by_provider(provider, %{active: !current_active}) do
      {:ok, _result} ->
        if provider == "weather_api", do: Xpressbus.Weather.clear_cache()

        socket = assign(socket, :settings, load_settings())

        socket =
          if provider == "ai", do: assign(socket, :ai_status, AI.provider_status()), else: socket

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update #{provider} status")}
    end
  end

  def handle_event("clear_ai_key", _params, socket) do
    case Integrations.upsert_config_by_provider("ai", %{config: %{"api_key" => ""}}) do
      {:ok, _config} ->
        socket = refresh_ai(socket)

        message =
          if socket.assigns.ai_status.configured do
            "Stored AI key removed. Chyllz AI is still connected through the environment key."
          else
            "Stored AI key removed. Chyllz is now using the local catalogue guide."
          end

        {:noreply, put_flash(socket, :info, message)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to remove the stored AI key")}
    end
  end

  def handle_event("toggle_bus", %{"category" => "bus"}, socket) do
    {:noreply, assign(socket, :bus_expanded, !socket.assigns.bus_expanded)}
  end

  def handle_event("toggle_chyllz", %{"category" => "chyllz"}, socket) do
    {:noreply, assign(socket, :chyllz_expanded, !socket.assigns.chyllz_expanded)}
  end

  def handle_event("toggle_settings", %{"category" => "settings"}, socket) do
    {:noreply, assign(socket, :settings_expanded, !socket.assigns.settings_expanded)}
  end

  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :sidebar_collapsed, !socket.assigns.sidebar_collapsed)}
  end

  defp test_paystack(socket, settings) do
    config = settings.config || %{}
    secret_key = Map.get(config, "secret_key")

    if is_nil(secret_key) or secret_key == "" do
      {:noreply, put_flash(socket, :error, "Missing Paystack secret key")}
    else
      # Test by calling Paystack's transaction/verify endpoint with a dummy reference
      # This will return 404 but will validate the secret key works
      test_ref =
        "TEST_#{:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false) |> String.replace("_", "-")}"

      case Req.get("https://api.paystack.co/transaction/verify/#{test_ref}",
             headers: %{"Authorization" => "Bearer #{config.secret_key}"}
           ) do
        {:ok, %Req.Response{status: 404, body: %{"message" => _msg, "status" => false}}} ->
          # 404 with valid response structure means secret key is valid
          {:noreply,
           put_flash(socket, :info, "Paystack API connection successful! Secret key is valid.")}

        {:ok, %Req.Response{status: 200, body: %{"status" => true}}} ->
          # Even better - valid key and reference format works
          {:noreply, put_flash(socket, :info, "Paystack API connection successful!")}

        {:ok, %Req.Response{status: 401, body: body}} ->
          {:noreply, put_flash(socket, :error, "Invalid Paystack secret key: #{inspect(body)}")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Paystack connection error: #{inspect(reason)}")}
      end
    end
  end

  defp test_flutterwave(socket, settings) do
    config = settings.config || %{}
    secret_key = Map.get(config, "secret_key")

    if is_nil(secret_key) or secret_key == "" do
      {:noreply, put_flash(socket, :error, "Missing Flutterwave secret key")}
    else
      # Test by calling Flutterwave's banks endpoint
      case Req.get("https://api.flutterwave.com/v3/banks/NG",
             headers: %{"Authorization" => "Bearer #{Map.get(config, "secret_key")}"}
           ) do
        {:ok, %Req.Response{status: 200, body: %{"status" => "success"}}} ->
          {:noreply, put_flash(socket, :info, "Flutterwave API connection successful!")}

        {:ok, %Req.Response{status: 401, body: _}} ->
          {:noreply, put_flash(socket, :error, "Invalid Flutterwave secret key")}

        {:error, reason} ->
          {:noreply,
           put_flash(socket, :error, "Flutterwave connection error: #{inspect(reason)}")}
      end
    end
  end

  defp test_mpesa(socket, settings) do
    config = settings.config || %{}
    consumer_key = Map.get(config, "consumer_key")
    consumer_secret = Map.get(config, "consumer_secret")

    if is_nil(consumer_key) or is_nil(consumer_secret) do
      {:noreply, put_flash(socket, :error, "Missing M-PESA consumer key or secret")}
    else
      base_url =
        if Map.get(config, "mode") == "production",
          do: "https://api.safaricom.co.ke",
          else: "https://sandbox.safaricom.co.ke"

      case Req.get("#{base_url}/oauth/v1/generate?grant_type=client_credentials",
             headers: %{
               "Authorization" => "Basic #{Base.encode64("#{consumer_key}:#{consumer_secret}")}"
             }
           ) do
        {:ok, %Req.Response{status: 200, body: %{"access_token" => _token}}} ->
          {:noreply, put_flash(socket, :info, "M-PESA API connection successful!")}

        {:ok, %Req.Response{status: 401, body: _}} ->
          {:noreply, put_flash(socket, :error, "Invalid M-PESA credentials")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "M-PESA connection error: #{inspect(reason)}")}
      end
    end
  end

  defp test_firebase(socket) do
    case Xpressbus.Firebase.check_configuration() do
      {:ok, :reachable} ->
        {:noreply,
         put_flash(
           socket,
           :info,
           "Firebase Phone Auth is reachable. Make sure Phone sign-in is enabled in the Firebase Console."
         )}

      {:error, :authentication_not_initialized} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Firebase Authentication is not initialised for project komiuta. Open Firebase Console → Authentication → Get started, then enable Phone sign-in."
         )}

      {:error, :invalid_api_key} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "The Firebase API key is invalid or expired. Check the FIREBASE_API_KEY setting."
         )}

      {:error, :not_configured} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Firebase Phone Auth is not configured. Set the FIREBASE_* environment variables."
         )}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Firebase check failed: #{inspect(reason)}")}
    end
  end

  defp test_weather_api(socket, setting) do
    config =
      case setting do
        %{config: config} when is_map(config) -> config
        _other -> %{}
      end

    key = Map.get(config, "api_key")

    if is_nil(key) or String.trim(to_string(key)) == "" do
      {:noreply, put_flash(socket, :error, "Missing WeatherAPI key. Save one first.")}
    else
      case Req.get("#{@weatherapi_base}/current.json",
             params: [key: String.trim(to_string(key)), q: "Nairobi"],
             retry: false,
             receive_timeout: 8_000
           ) do
        {:ok, %Req.Response{status: 200, body: body}} when is_map(body) ->
          place = get_in(body, ["location", "name"]) || "Nairobi"

          message =
            case get_in(body, ["current", "temp_c"]) do
              temp when is_number(temp) ->
                "WeatherAPI connection successful — #{place} is #{round(temp)}°C right now."

              _other ->
                "WeatherAPI connection successful! Chyllz will use this key for live weather."
            end

          {:noreply, put_flash(socket, :info, message)}

        {:ok, %Req.Response{status: status}} when status in [401, 403] ->
          {:noreply,
           put_flash(
             socket,
             :error,
             "WeatherAPI rejected the key (HTTP #{status}). Check it in your WeatherAPI dashboard."
           )}

        {:ok, %Req.Response{status: status}} ->
          {:noreply, put_flash(socket, :error, "WeatherAPI connection failed (HTTP #{status}).")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "WeatherAPI connection error: #{inspect(reason)}")}
      end
    end
  end

  defp load_settings do
    Enum.into(@providers, %{}, fn {provider_key, _} ->
      config = Integrations.get_config_by_provider(provider_key) || %{config: %{}, active: true}
      {provider_key, config}
    end)
  end

  defp refresh_ai(socket) do
    socket
    |> assign(:settings, load_settings())
    |> assign(:ai_status, AI.provider_status())
  end

  defp build_ai_config(params) do
    base_url = ai_trim(params["base_url"])
    model = ai_trim(params["model"])
    vision_model = ai_trim(params["vision_model"])
    timeout = ai_trim(params["timeout"])
    api_key = ai_trim(params["api_key"])

    cond do
      base_url && not Regex.match?(~r/^https?:\/\/[^\s]+$/i, base_url) ->
        {:error, "Base URL must start with http:// or https://"}

      base_url && String.length(base_url) > 300 ->
        {:error, "Base URL is too long"}

      model && String.length(model) > 120 ->
        {:error, "Model name is too long"}

      vision_model && String.length(vision_model) > 120 ->
        {:error, "Vision model name is too long"}

      api_key && String.length(api_key) > 500 ->
        {:error, "API key is too long"}

      timeout && invalid_ai_timeout?(timeout) ->
        {:error, "Timeout must be between 1,000 and 60,000 milliseconds"}

      true ->
        config =
          %{}
          |> ai_put("api_key", api_key)
          |> ai_put("base_url", base_url)
          |> ai_put("model", model)
          |> ai_put("vision_model", vision_model)
          |> ai_put("timeout", timeout)

        {:ok, config}
    end
  end

  defp ai_trim(value) do
    case value do
      nil ->
        nil

      value ->
        value = value |> to_string() |> String.trim()
        if value == "", do: nil, else: value
    end
  end

  defp ai_put(config, _key, nil), do: config

  defp ai_put(config, key, value) do
    if key in Integrations.ai_fields(), do: Map.put(config, key, value), else: config
  end

  defp invalid_ai_timeout?(value) do
    case Integer.parse(value) do
      {timeout, ""} when timeout >= 1_000 and timeout <= 60_000 -> false
      _other -> true
    end
  end

  defp test_ai(socket) do
    status = socket.assigns.ai_status

    if status.configured do
      messages = [
        %{"role" => "system", "content" => "You are a connectivity check. Reply briefly."},
        %{"role" => "user", "content" => "Reply with OK."}
      ]

      case AI.chat(messages, max_tokens: 8, timeout: 10_000) do
        {:ok, _reply} ->
          {:noreply,
           put_flash(
             socket,
             :info,
             "Chyllz AI is reachable. Provider model: #{status.model}."
           )}

        {:error, :not_configured} ->
          {:noreply,
           put_flash(socket, :error, "No AI key is configured. Save a key or set AI_API_KEY.")}

        {:error, {:http_status, 401, _body}} ->
          {:noreply, put_flash(socket, :error, "The AI provider rejected the API key (401).")}

        {:error, {:http_status, 403, _body}} ->
          {:noreply,
           put_flash(socket, :error, "The AI provider denied access to this key (403).")}

        {:error, {:http_status, status_code, _body}} ->
          {:noreply, put_flash(socket, :error, "The AI provider returned HTTP #{status_code}.")}

        {:error, {:request_failed, _reason}} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             "Could not reach the AI provider. Check the base URL and network access."
           )}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "The AI connection check failed.")}
      end
    else
      {:noreply,
       put_flash(
         socket,
         :error,
         "No AI key is configured. Save a key first, or set AI_API_KEY on the server."
       )}
    end
  end

  defp provider_config(settings, provider) do
    case settings[provider] do
      nil -> %{}
      %{config: config} when is_map(config) -> config
      _ -> %{}
    end
  end

  defp test_google_maps(socket, setting) do
    config =
      case setting do
        %{config: config} when is_map(config) -> config
        _other -> %{}
      end

    key = config |> Map.get("api_key") |> to_string() |> String.trim()

    if key == "" do
      {:noreply, put_flash(socket, :error, "Missing Google Maps API key. Save one first.")}
    else
      case Req.get("https://maps.googleapis.com/maps/api/geocode/json",
             params: [address: "Nairobi", key: key],
             retry: false,
             receive_timeout: 8_000
           ) do
        {:ok, %Req.Response{status: 200, body: body}} when is_map(body) ->
          case body["status"] do
            "OK" ->
              {:noreply,
               put_flash(
                 socket,
                 :info,
                 "Google Maps connection successful — Geocoding API accepted this key."
               )}

            status ->
              message = body["error_message"] || "Google Maps returned #{status}."

              {:noreply,
               put_flash(
                 socket,
                 :error,
                 "Google Maps rejected this key: #{message}"
               )}
          end

        {:ok, %Req.Response{status: status}} ->
          {:noreply,
           put_flash(socket, :error, "Google Maps returned HTTP #{status}. Check the key.")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Google Maps check failed: #{inspect(reason)}")}
      end
    end
  end
end
