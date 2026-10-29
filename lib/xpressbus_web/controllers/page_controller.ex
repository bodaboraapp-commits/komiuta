defmodule XpressbusWeb.PageController do
  use XpressbusWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
