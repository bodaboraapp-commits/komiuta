defmodule XpressbusWeb.AdminController do
  use XpressbusWeb, :controller
  alias Xpressbus.Admins
  alias XpressbusWeb.Plugs.IpThrottle

  @max_email_attempts 5
  @email_attempt_window :timer.minutes(15) |> div(1_000)

  def login(conn, _params) do
    conn
    |> assign(:page_title, "Admin Login")
    |> render(:login)
  end

  def authenticate(conn, %{"admin" => admin_params}) do
    email = admin_params["email"] |> to_string() |> String.trim() |> String.downcase()
    password = to_string(admin_params["password"] || "")
    throttle_key = if email == "", do: "blank", else: email

    case IpThrottle.allow?(:admin_login, throttle_key, @max_email_attempts, @email_attempt_window) do
      {:error, retry_after} ->
        conn
        |> put_resp_header("retry-after", Integer.to_string(retry_after))
        |> put_status(:too_many_requests)
        |> put_flash(
          :error,
          "Too many failed sign-in attempts for this account. Please wait 15 minutes and try again."
        )
        |> render(:login)

      {:ok, _attempt} ->
        authenticate_with_password(conn, email, password, throttle_key)
    end
  end

  defp authenticate_with_password(conn, email, password, throttle_key) do
    admin = Admins.get_by_email(email)

    cond do
      is_nil(admin) ->
        invalid_credentials(conn)

      not Admins.verify_password(password, admin.hashed_password) ->
        invalid_credentials(conn)

      true ->
        IpThrottle.clear(:admin_login, throttle_key)

        conn
        |> put_session(:admin_id, admin.id)
        |> put_flash(:success, "Welcome back!")
        |> redirect(to: ~p"/admin/dashboard")
    end
  end

  defp invalid_credentials(conn) do
    conn
    |> put_flash(:error, "Invalid email or password")
    |> render(:login)
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "Logged out successfully")
    |> redirect(to: ~p"/admin/login")
  end

  def dashboard_redirect(conn, _params) do
    redirect(conn, to: ~p"/admin/dashboard")
  end
end
