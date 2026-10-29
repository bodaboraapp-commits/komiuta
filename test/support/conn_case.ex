defmodule XpressbusWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use XpressbusWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint XpressbusWeb.Endpoint

      use XpressbusWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import XpressbusWeb.ConnCase
    end
  end

  setup tags do
    # LiveView tests render the page on the server, so they touch the database.
    # Starting a sandbox owner here keeps every connection test isolated.
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Xpressbus.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
