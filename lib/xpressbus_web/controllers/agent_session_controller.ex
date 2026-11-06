defmodule XpressbusWeb.AgentSessionController do
  use XpressbusWeb, :controller

  alias Xpressbus.Agents

  @page_assigns [
    page_manifest: "/agent-manifest.json",
    page_app_name: "KOMIUTA Agent",
    page_apple_touch_icon: "/images/agent-icon-180.png",
    page_theme_color: "#ffffff"
  ]

  def login(conn, _params) do
    if get_session(conn, :agent_id) do
      redirect(conn, to: "/agent/account")
    else
      render(
        conn,
        :login,
        [page_title: "KOMIUTA Agent — Log in", identifier: ""] ++ @page_assigns
      )
    end
  end

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
          [page_title: "KOMIUTA Agent — Log in", identifier: identifier] ++ @page_assigns
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
    case Agents.get_application(agent_id) do
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
