defmodule XpressbusWeb.AgentSessionController do
  use XpressbusWeb, :controller

  alias Xpressbus.Agents
  alias Xpressbus.Integrations

  @page_assigns [
    page_manifest: "/agent-manifest.json",
    page_app_name: "KOMIUTA Agent",
    page_apple_touch_icon: "/images/agent-icon-180.png",
    page_theme_color: "#ffffff"
  ]

  def login(conn, params) do
    if get_session(conn, :agent_id) do
      redirect(conn, to: "/agent/account")
    else
      conn
      |> apply_google_error(params)
      |> render(:login, login_assigns(""))
    end
  end

  def google_start(conn, _params) do
    if String.starts_with?(conn.host, "agent.") do
      redirect(conn, external: XpressbusWeb.Endpoint.url() <> "/agent/google/start")
    else
      conn
      |> configure_session(renew: true)
      |> put_session(:agent_google_pending, true)
      |> redirect(to: "/auth/google")
    end
  end

  def google_complete(conn, %{"token" => token}) do
    case Phoenix.Token.verify(XpressbusWeb.Endpoint, "agent-google-login", token, max_age: 300) do
      {:ok, agent_id} ->
        case Agents.get_application(agent_id) do
          %{} = application ->
            conn
            |> configure_session(renew: true)
            |> delete_session(:agent_login_id)
            |> put_session(:agent_id, application.id)
            |> put_flash(:info, "Signed in with Google as #{application.email}.")
            |> redirect(to: "/agent/account")

          _ ->
            redirect(conn, to: "/agent/login?" <> URI.encode_query(%{"google_error" => "failed"}))
        end

      _ ->
        redirect(conn, to: "/agent/login?" <> URI.encode_query(%{"google_error" => "failed"}))
    end
  end

  def google_complete(conn, _params) do
    redirect(conn, to: "/agent/login?" <> URI.encode_query(%{"google_error" => "failed"}))
  end

  @doc """
  Verifies a Firebase Phone Auth ID token and starts the agent session.

  Firebase proves the agent owns the phone number on their application, so no
  password or email code is needed.
  """
  def firebase_verify(conn, params) do
    token =
      params["id_token"] ||
        get_in(params, ["firebase", "id_token"]) ||
        ""

    token = if is_binary(token), do: String.trim(token), else: ""

    cond do
      not Xpressbus.Firebase.configured?() ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "SMS login is not configured yet. Please contact support."})

      token == "" ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Missing Firebase verification token."})

      true ->
        case Xpressbus.Firebase.verify_id_token(token) do
          {:ok, phone} ->
            case Agents.find_by_phone(phone) do
              %Xpressbus.Agents.AgentApplication{} = application ->
                conn
                |> configure_session(renew: true)
                |> put_session(:agent_id, application.id)
                |> json(%{ok: true, redirect: "/agent/account"})

              nil ->
                conn
                |> put_status(:not_found)
                |> json(%{
                  error:
                    "No agent application was found for that phone number. Apply for an agent account first."
                })
            end

          {:error, :not_configured} ->
            conn
            |> put_status(:service_unavailable)
            |> json(%{error: "SMS login is not configured yet. Please contact support."})

          {:error, _reason} ->
            conn
            |> put_status(:unauthorized)
            |> json(%{error: "That SMS code could not be verified. Please try again."})
        end
    end
  end

  defp login_assigns(identifier) do
    google_config = Integrations.get_config_by_provider("google")

    google_enabled =
      case google_config do
        %{active: true, config: config} when is_map(config) ->
          String.trim(to_string(config["client_id"] || "")) != "" and
            String.trim(to_string(config["client_secret"] || "")) != ""

        _ ->
          false
      end

    [
      page_title: "KOMIUTA Agent — Sign in",
      identifier: identifier,
      firebase_config: Xpressbus.Firebase.client_config(),
      firebase_configured: Xpressbus.Firebase.configured?(),
      google_enabled: google_enabled,
      google_start_url: XpressbusWeb.Endpoint.url() <> "/agent/google/start"
    ] ++ @page_assigns
  end

  defp apply_google_error(conn, %{"google_error" => "no_agent"}) do
    put_flash(
      conn,
      :error,
      "No agent application was found for that Google email. Apply first or use the phone on your application."
    )
  end

  defp apply_google_error(conn, %{"google_error" => "failed"}) do
    put_flash(conn, :error, "Google sign-in could not be completed. Please try again.")
  end

  defp apply_google_error(conn, _params), do: conn

  @doc """
  Emails a one-time sign-in code. The application itself is the agent account,
  so no separate password is stored or checked.
  """
  def request_code(conn, %{"agent" => params}) do
    identifier = String.trim(to_string(params["identifier"] || ""))

    case Agents.request_login_code(identifier) do
      {:ok, application} ->
        conn
        |> configure_session(renew: true)
        |> put_session(:agent_login_id, application.id)
        |> put_flash(:info, "We sent a 6-digit code to #{application.email}.")
        |> redirect(to: "/agent/verify")

      {:error, reason} ->
        conn
        |> put_flash(:error, error_message(reason))
        |> render(
          :login,
          login_assigns(identifier)
        )
    end
  end

  def verify(conn, _params) do
    case pending_login_application(conn) do
      {:ok, application} ->
        render(
          conn,
          :verify,
          [
            page_title: "KOMIUTA Agent — Verify code",
            identifier: application.email,
            expires_in_minutes: Agents.login_code_ttl_minutes()
          ] ++ @page_assigns
        )

      :error ->
        conn
        |> put_flash(:error, "Start by requesting a sign-in code.")
        |> redirect(to: "/agent/login")
    end
  end

  def verify_code(conn, %{"agent" => params}) do
    case pending_login_application(conn) do
      {:ok, application} ->
        code = String.trim(to_string(params["code"] || ""))

        case Agents.verify_login_code(application.id, code) do
          {:ok, application} ->
            conn
            |> configure_session(renew: true)
            |> delete_session(:agent_login_id)
            |> put_session(:agent_id, application.id)
            |> put_flash(:info, "Welcome back, #{first_name(application.full_name)}.")
            |> redirect(to: "/agent/account")

          {:error, reason} ->
            conn
            |> put_flash(:error, error_message(reason))
            |> render(
              :verify,
              [
                page_title: "KOMIUTA Agent — Verify code",
                identifier: application.email,
                expires_in_minutes: Agents.login_code_ttl_minutes()
              ] ++ @page_assigns
            )
        end

      :error ->
        conn
        |> put_flash(:error, "Start by requesting a sign-in code.")
        |> redirect(to: "/agent/login")
    end
  end

  def resend_code(conn, _params) do
    case pending_login_application(conn) do
      {:ok, application} ->
        case Agents.resend_login_code(application.id) do
          {:ok, _application} ->
            conn
            |> put_flash(:info, "A new code has been sent to #{application.email}.")
            |> redirect(to: "/agent/verify")

          {:error, reason} ->
            conn
            |> put_flash(:error, error_message(reason))
            |> render(
              :verify,
              [
                page_title: "KOMIUTA Agent — Verify code",
                identifier: application.email,
                expires_in_minutes: Agents.login_code_ttl_minutes()
              ] ++ @page_assigns
            )
        end

      :error ->
        conn
        |> put_flash(:error, "Start by requesting a sign-in code.")
        |> redirect(to: "/agent/login")
    end
  end

  def account(conn, _params) do
    case get_session(conn, :agent_id) |> load_agent() do
      {:ok, application} ->
        render(
          conn,
          :account,
          [page_title: "KOMIUTA Agent — Account", agent: application] ++ @page_assigns
        )

      :error ->
        conn
        |> put_flash(:error, "Please log in to view your agent account.")
        |> redirect(to: "/agent/login")
    end
  end

  def logout(conn, _params) do
    conn
    |> delete_session(:agent_id)
    |> delete_session(:agent_login_id)
    |> put_flash(:info, "You have been logged out.")
    |> redirect(to: "/agent/login")
  end

  defp pending_login_application(conn) do
    case get_session(conn, :agent_login_id) |> load_agent() do
      {:ok, application} -> {:ok, application}
      :error -> :error
    end
  end

  defp load_agent(nil), do: :error

  defp load_agent(agent_id) do
    case Agents.get_application_with_bus_operator(agent_id) do
      %{} = application -> {:ok, application}
      _ -> :error
    end
  end

  defp first_name(nil), do: "Agent"
  defp first_name(name), do: name |> to_string() |> String.split() |> List.first()

  defp error_message(:not_found),
    do: "No agent application was found for that email or phone number."

  defp error_message(:missing_email),
    do: "That agent application does not have an email address for a sign-in code."

  defp error_message(:delivery_failed),
    do: "We could not send the sign-in code. Please try again."

  defp error_message({:cooldown, _application}),
    do: "Please wait a minute before requesting another sign-in code."

  defp error_message({:rate_limited, _application}),
    do: "Too many sign-in codes requested. Please wait an hour and try again."

  defp error_message(:no_code),
    do: "That code is no longer valid. Request a new one."

  defp error_message(:expired),
    do: "That code has expired. Request a new one."

  defp error_message(:too_many_attempts),
    do: "Too many incorrect attempts. Request a new code."

  defp error_message(:invalid),
    do: "That code is incorrect. Please check it and try again."
end
