defmodule XpressbusWeb.AuthController do
  use XpressbusWeb, :controller
  plug Ueberauth

  alias Xpressbus.Accounts
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

    conn
    |> put_flash(:error, "Failed to authenticate with Google.")
    |> redirect(to: ~p"/user/login")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
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
end
