defmodule XpressbusWeb.AdminController do
  use XpressbusWeb, :controller
  alias Xpressbus.Admins

  def login(conn, _params) do
    render(conn, :login)
  end

  def authenticate(conn, %{"admin" => admin_params}) do
    email = String.trim(admin_params["email"] || "")
    password = admin_params["password"] || ""

    admin = Admins.get_by_email(email)

    cond do
      is_nil(admin) ->
        conn
        |> put_flash(:error, "Invalid email or password")
        |> render(:login)

      not Admins.verify_password(password, admin.hashed_password) ->
        conn
        |> put_flash(:error, "Invalid email or password")
        |> render(:login)

      true ->
        conn
        |> put_session(:admin_id, admin.id)
        |> put_flash(:success, "Welcome back!")
        |> redirect(to: ~p"/admin/dashboard")
    end
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
