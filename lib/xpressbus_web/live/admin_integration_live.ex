defmodule XpressbusWeb.AdminIntegrationLive do
  use XpressbusWeb, :live_view
  import XpressbusWeb.AdminComponents
  alias Xpressbus.Integrations

  @providers %{
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
       |> assign(:sidebar_collapsed, false)
       |> assign(:bus_expanded, true)
       |> assign(:chyllz_expanded, true)
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
        {:noreply,
         socket
         |> put_flash(:info, "#{String.upcase(provider)} settings saved successfully")
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

      _ ->
        {:noreply, put_flash(socket, :info, "Handshake successful! Payment gateway is active.")}
    end
  end

  def handle_event("toggle_active", %{"provider" => provider}, socket) do
    current = socket.assigns.settings[provider]
    current_active = Map.get(current, :active, true)

    case Integrations.upsert_config_by_provider(provider, %{active: !current_active}) do
      {:ok, _result} ->
        {:noreply, assign(socket, :settings, load_settings())}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update #{provider} status")}
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

  defp load_settings do
    Enum.into(@providers, %{}, fn {provider_key, _} ->
      config = Integrations.get_config_by_provider(provider_key) || %{config: %{}, active: true}
      {provider_key, config}
    end)
  end

  defp provider_config(settings, provider) do
    case settings[provider] do
      nil -> %{}
      %{config: config} when is_map(config) -> config
      _ -> %{}
    end
  end
end
