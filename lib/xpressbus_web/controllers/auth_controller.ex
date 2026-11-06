defmodule XpressbusWeb.AuthController do
  use XpressbusWeb, :controller
  plug Ueberauth

  alias Xpressbus.Accounts
  alias Xpressbus.Agents
  require Logger

  def request(conn, %{"provider" => "google"}) do
    # The config is already injected by the Plug XpressbusWeb.Plugs.GoogleAuthConfig
    # We just need to make sure Ueberauth uses the private options
    opts = conn.private[:ueberauth_request_options] || []

    Logger.info("AuthController Request Phase - Using opts: #{inspect(opts)}")

    Ueberauth.run_request(conn, "google", opts)
  end

  def callback(%{assigns: %{ueberauth_failure: fails}} = conn, _params) do
    Logger.error("Google Auth Failure: #{inspect(fails)}")

    if agent_google_pending?(conn) do
      conn
      |> delete_session(:agent_google_pending)
      |> redirect(external: agent_login_url("failed"))
    else
      conn
      |> put_flash(:error, "Failed to authenticate with Google.")
      |> redirect(to: ~p"/user/login")
    end
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    if agent_google_pending?(conn) do
      complete_agent_google(conn, auth)
    else
      complete_traveller_google(conn, auth)
    end
  end

  defp complete_traveller_google(conn, auth) do
    user_info = %{
      name: auth.info.name,
      email: auth.info.email,
      google_id: auth.uid
    }

    case Accounts.find_or_create_google_user(user_info) do
      {:ok, user} ->
        conn =
          conn
          |> put_session(:user_id, user.id)
          |> put_session(:user_name, user.name)

        if Accounts.profile_complete?(user) do
          conn
          |> put_flash(:info, "Successfully authenticated.")
          |> redirect(to: ~p"/dashboard")
        else
          conn
          |> put_flash(:info, "One last step: add your phone number to finish setting up.")
          |> redirect(to: ~p"/user/complete-profile")
        end

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Authentication failed. Please try again.")
        |> redirect(to: ~p"/user/login")
    end
  end

  defp complete_agent_google(conn, auth) do
    email = auth.info.email |> to_string() |> String.trim()

    conn =
      conn
      |> delete_session(:agent_google_pending)

    case Agents.find_by_email(email) do
      %Xpressbus.Agents.AgentApplication{} = application ->
        token =
          Phoenix.Token.sign(XpressbusWeb.Endpoint, "agent-google-login", application.id,
            max_age: 300
          )

        conn
        |> redirect(
          external:
            agent_base_url() <>
              "/agent/google/complete?" <> URI.encode_query(%{"token" => token})
        )

      nil ->
        redirect(conn, external: agent_login_url("no_agent"))
    end
  end

  defp agent_google_pending?(conn), do: get_session(conn, :agent_google_pending) == true

  defp agent_base_url do
    Application.get_env(:xpressbus, :agent_app_url, "https://agent.komiuta.com")
    |> to_string()
    |> String.trim_trailing("/")
  end

  defp agent_login_url(reason) do
    agent_base_url() <> "/agent/login?" <> URI.encode_query(%{"google_error" => reason})
  end
end
