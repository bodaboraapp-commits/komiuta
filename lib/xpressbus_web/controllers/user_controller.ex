defmodule XpressbusWeb.UserController do
  use XpressbusWeb, :controller
  alias Xpressbus.Accounts

  def login(conn, _params) do
    render(conn, :login)
  end

  def registration(conn, _params) do
    render(conn, :registration)
  end

  def authenticate(conn, %{"user" => user_params}) do
    phone = String.trim(user_params["phone"] || "")

    if phone != "" do
      case Accounts.get_user_by_phone(phone) do
        nil ->
          conn
          |> put_flash(:error, "No account found with this phone number. Please sign up first.")
          |> redirect(to: ~p"/user/signup")

        _user ->
          conn
          |> put_session(:user_id, phone)
          |> put_flash(:success, "Welcome back!")
          |> redirect(to: ~p"/dashboard")
      end
    else
      conn
      |> put_flash(:error, "Please enter your phone number")
      |> render(:login)
    end
  end

  def register(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        conn
        |> put_session(:user_id, user.phone)
        |> put_flash(:success, "Registration successful! Welcome to Komiuta.")
        |> redirect(to: ~p"/dashboard")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Registration failed. Please check your details or phone number.")
        |> render(:registration)
    end
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "Logged out successfully")
    |> redirect(to: ~p"/")
  end
end
