defmodule XpressbusWeb.AgentSessionController do
  use XpressbusWeb, :controller

  alias Xpressbus.Agents
  alias Xpressbus.AgentDashboard
  alias Xpressbus.AgentTags
  alias Xpressbus.Integrations
  alias XpressbusWeb.Endpoint

  @page_assigns [
    page_manifest: "/agent-manifest.json",
    page_app_name: "KOMIUTA Agent",
    page_apple_touch_icon: "/images/agent-icon-180.png",
    page_theme_color: "#ffffff"
  ]

  def login(conn, params) do
    case get_session(conn, :agent_id) |> load_agent() do
      {:ok, application} ->
        redirect(conn, to: next_path(application))

      :error ->
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
            application = mark_google_email_verified(application)

            conn
            |> configure_session(renew: true)
            |> delete_session(:agent_login_id)
            |> put_session(:agent_id, application.id)
            |> put_flash(:info, "Signed in with Google as #{application.email}.")
            |> redirect(to: next_path(application))

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
                |> json(%{ok: true, redirect: next_path(application)})

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
  Starts an agent login. Agents normally sign in with the phone number on their
  application (we text a one-time code; if SMS is unavailable we email it).
  Email identifiers keep working for anyone who still types their email.
  """
  def request_code(conn, %{"agent" => params}) do
    identifier = String.trim(to_string(params["identifier"] || ""))

    result =
      if String.contains?(identifier, "@") do
        Agents.request_login_code(identifier)
      else
        Agents.request_phone_login_code(identifier)
      end

    case result do
      {:ok, application} ->
        conn
        |> configure_session(renew: true)
        |> put_session(:agent_login_id, application.id)
        |> put_flash(:info, "We sent a 6-digit code to #{application.email}.")
        |> redirect(to: "/agent/verify")

      {:ok, application, delivery} ->
        conn
        |> configure_session(renew: true)
        |> put_session(:agent_login_id, application.id)
        |> put_flash(:info, phone_login_message(application, delivery))
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
            identifier: identifier_for(application),
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
            |> redirect(to: next_path(application))

          {:error, reason} ->
            conn
            |> put_flash(:error, error_message(reason))
            |> render(
              :verify,
              [
                page_title: "KOMIUTA Agent — Verify code",
                identifier: identifier_for(application),
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
        case Agents.resend_phone_login_code(application.id) do
          {:ok, _application, delivery} ->
            conn
            |> put_flash(:info, resend_message(application, delivery))
            |> redirect(to: "/agent/verify")

          {:error, reason} ->
            conn
            |> put_flash(:error, error_message(reason))
            |> render(
              :verify,
              [
                page_title: "KOMIUTA Agent — Verify code",
                identifier: identifier_for(application),
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

  def verify_email(conn, _params) do
    case get_session(conn, :agent_id) |> load_agent() do
      {:ok, application} ->
        if Agents.email_verified?(application) do
          redirect(conn, to: next_path(application))
        else
          render_verify_email(conn, application, pending_email(conn, application))
        end

      :error ->
        conn
        |> put_flash(:error, "Please log in to verify your email.")
        |> redirect(to: "/agent/login")
    end
  end

  def send_email_verification(conn, %{"email" => email}) do
    case get_session(conn, :agent_id) |> load_agent() do
      {:ok, application} ->
        case Agents.request_email_verification(application, email) do
          {:ok, email} ->
            conn
            |> put_session(:agent_verify_email, email)
            |> put_flash(:info, "We sent a 6-digit code to #{email}.")
            |> redirect(to: "/agent/verify-email")

          {:error, reason} ->
            conn
            |> put_flash(:error, error_message(reason))
            |> render_verify_email(application, to_string(email || ""))
        end

      :error ->
        conn
        |> put_flash(:error, "Please log in to verify your email.")
        |> redirect(to: "/agent/login")
    end
  end

  def confirm_email_verification(conn, %{"code" => code}) do
    case get_session(conn, :agent_id) |> load_agent() do
      {:ok, application} ->
        pending_email = pending_email(conn, application)
        code = String.trim(to_string(code || ""))

        case Agents.verify_email_code(application, code) do
          {:ok, application} ->
            case Agents.mark_email_verified(application, pending_email) do
              {:ok, verified_application} ->
                conn
                |> delete_session(:agent_verify_email)
                |> put_flash(:info, "Email verified. Welcome to your dashboard.")
                |> redirect(to: next_path(verified_application))

              {:error, _changeset} ->
                conn
                |> put_flash(:error, "That email is already linked to another agent account.")
                |> render_verify_email(application, pending_email)
            end

          {:error, reason} ->
            conn
            |> put_flash(:error, error_message(reason))
            |> render_verify_email(application, pending_email)
        end

      :error ->
        conn
        |> put_flash(:error, "Please log in to verify your email.")
        |> redirect(to: "/agent/login")
    end
  end

  @doc """
  Prints the approved agent's physical ID tag. The QR code is scanned by staff
  or partners to open the public verification page.
  """
  def tag(conn, _params) do
    case get_session(conn, :agent_id) |> load_agent() do
      {:ok, %{status: "approved"} = application} ->
        token = AgentTags.token(application)
        verify_url = Endpoint.url() <> "/agent/verified/" <> token

        render(
          conn,
          :tag,
          [
            page_title: "KOMIUTA Agent — Verified ID tag",
            page_robots: "noindex,nofollow",
            agent: application,
            tag_token: token,
            verify_url: verify_url,
            tag_qr:
              XpressbusWeb.QRCode.svg(verify_url,
                aria_label: "Scan to verify this Komiuta agent",
                size: 132
              ),
            initials: AgentTags.initials(application),
            issued_on: AgentTags.issued_on(application)
          ] ++ @page_assigns
        )

      {:ok, _application} ->
        conn
        |> put_flash(
          :error,
          "Your verified ID tag becomes available once your application is approved."
        )
        |> redirect(to: "/agent/account")

      :error ->
        conn
        |> put_flash(:error, "Please log in to view your agent ID tag.")
        |> redirect(to: "/agent/login")
    end
  end

  @doc "Public page opened by scanning the QR code on a printed agent tag."
  def verified_agent(conn, %{"token" => token}) do
    case AgentTags.verify(token) do
      {:ok, application_id} ->
        case Agents.get_application_with_bus_operator(application_id) do
          %{status: "approved"} = application ->
            render(
              conn,
              :verified_agent,
              [
                page_title: "KOMIUTA Agent — Verified agent",
                page_robots: "noindex,nofollow",
                agent: application
              ] ++ @page_assigns
            )

          _ ->
            render_agent_tag_invalid(conn)
        end

      _ ->
        render_agent_tag_invalid(conn)
    end
  end

  defp render_agent_tag_invalid(conn) do
    conn
    |> put_status(:not_found)
    |> render(
      :verified_agent,
      [page_title: "KOMIUTA Agent — Tag not valid", page_robots: "noindex,nofollow", agent: nil] ++
        @page_assigns
    )
  end

  def dashboard(conn, _params) do
    case get_session(conn, :agent_id) |> load_agent() do
      {:ok, application} ->
        cond do
          application.status == "approved" ->
            dashboard = AgentDashboard.load(application)

            render(
              conn,
              :dashboard,
              [
                page_title: "KOMIUTA Agent — Dashboard",
                agent: application,
                dashboard: dashboard,
                salutation: AgentDashboard.greeting()
              ] ++ @page_assigns
            )

          not Agents.email_verified?(application) ->
            conn
            |> put_flash(:info, "Verify your email address to continue to your dashboard.")
            |> redirect(to: "/agent/verify-email")

          true ->
            conn
            |> put_flash(
              :info,
              "Your dashboard unlocks when your agent application is approved."
            )
            |> redirect(to: "/agent/account")
        end

      :error ->
        conn
        |> put_flash(:error, "Please log in to view your agent dashboard.")
        |> redirect(to: "/agent/login")
    end
  end

  def bookings(conn, _params) do
    case get_session(conn, :agent_id) |> load_agent() do
      {:ok, %{status: "approved"} = application} ->
        render(
          conn,
          :bookings,
          [
            page_title: "KOMIUTA Agent — Partner bookings",
            agent: application,
            bookings: AgentDashboard.bookings(application),
            scope_label: AgentDashboard.scope_label(application)
          ] ++ @page_assigns
        )

      {:ok, _application} ->
        conn
        |> put_flash(:info, "Partner bookings appear once your agent application is approved.")
        |> redirect(to: "/agent/account")

      :error ->
        conn
        |> put_flash(:error, "Please log in to view partner bookings.")
        |> redirect(to: "/agent/login")
    end
  end

  def account(conn, _params) do
    case get_session(conn, :agent_id) |> load_agent() do
      {:ok, application} ->
        if Agents.email_verified?(application) do
          dashboard =
            if application.status == "approved" do
              AgentDashboard.load(application)
            end

          render(
            conn,
            :account,
            [
              page_title: "KOMIUTA Agent — Account",
              agent: application,
              dashboard: dashboard,
              salutation: AgentDashboard.greeting()
            ] ++ @page_assigns
          )
        else
          conn
          |> put_flash(:info, "Verify your email address to continue to your dashboard.")
          |> redirect(to: "/agent/verify-email")
        end

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
    |> delete_session(:agent_verify_email)
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

  defp next_path(application) do
    cond do
      application.status == "approved" -> "/agent/dashboard"
      not Agents.email_verified?(application) -> "/agent/verify-email"
      true -> "/agent/account"
    end
  end

  defp mark_google_email_verified(application) do
    if Agents.email_verified?(application) do
      application
    else
      case Agents.mark_email_verified(application, application.email) do
        {:ok, updated} -> updated
        {:error, _changeset} -> application
      end
    end
  end

  defp pending_email(conn, application) do
    get_session(conn, :agent_verify_email) || application.email || ""
  end

  defp render_verify_email(conn, application, email) do
    render(
      conn,
      :verify_email,
      [
        page_title: "KOMIUTA Agent — Verify email",
        agent: application,
        pending_email: email,
        code_sent: not is_nil(get_session(conn, :agent_verify_email))
      ] ++ @page_assigns
    )
  end

  defp identifier_for(application) do
    if is_binary(application.phone) and application.phone != "" do
      application.phone
    else
      application.email || ""
    end
  end

  defp phone_login_message(application, :sms_and_email) do
    "We sent your 6-digit code by SMS to #{identifier_for(application)} and by email to #{application.email}."
  end

  defp phone_login_message(application, :sms) do
    "We texted a 6-digit code to #{identifier_for(application)}."
  end

  defp phone_login_message(application, :email) do
    "Text message unavailable — we emailed your 6-digit code to #{application.email}."
  end

  defp resend_message(application, :sms_and_email) do
    "We resent your code by SMS to #{identifier_for(application)} and by email to #{application.email}."
  end

  defp resend_message(application, :sms) do
    "A new code has been sent by SMS to #{identifier_for(application)}."
  end

  defp resend_message(application, :email) do
    "Text message unavailable — a new code was emailed to #{application.email}."
  end

  defp first_name(nil), do: "Agent"
  defp first_name(name), do: name |> to_string() |> String.split() |> List.first()

  defp error_message(:invalid_email), do: "Enter a valid email address."

  defp error_message(:email_taken),
    do: "That email is already linked to another agent account."

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
