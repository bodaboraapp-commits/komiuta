defmodule XpressbusWeb.Plugs.AdminAuth do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if get_session(conn, :admin_id) do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(
        :error,
        "You must be logged in as an admin to access this page."
      )
      |> Phoenix.Controller.redirect(to: "/admin/login")
      |> halt()
    end
  end
end
