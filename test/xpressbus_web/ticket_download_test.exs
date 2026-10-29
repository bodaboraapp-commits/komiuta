defmodule XpressbusWeb.TicketDownloadTest do
  use XpressbusWeb.ConnCase, async: true

  import Xpressbus.AccountsFixtures

  alias Xpressbus.Repo
  alias Xpressbus.Tickets.Ticket

  defp unique_ticket_id do
    "TKT-" <> (System.unique_integer([:positive]) |> Integer.to_string())
  end

  defp create_ticket(user, overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          ticket_id: unique_ticket_id(),
          from: "Mombasa",
          to: "Nairobi",
          travel_date: ~D[2026-10-29],
          departure: "7:00 AM",
          arrival: "5:30 PM",
          company: "MashPoa",
          price: "KSH 2300",
          seats: "[\"6\"]",
          passenger_name: user.name,
          passenger_phone: user.phone,
          payment_method: "mpesa",
          status: "confirmed",
          type: "One Way"
        },
        overrides
      )

    Repo.insert!(struct(Ticket, attrs))
  end

  test "a signed-in passenger can download their own ticket as a PDF", %{conn: conn} do
    user = user_fixture()
    ticket = create_ticket(user)

    conn =
      conn
      |> Plug.Test.init_test_session(%{user_id: user.id})
      |> get(~p"/user/tickets/#{ticket.ticket_id}/download")

    assert response(conn, 200) =~ "%PDF-1.4"
    assert get_resp_header(conn, "content-type") |> hd() =~ "application/pdf"
    assert get_resp_header(conn, "content-disposition") |> hd() =~ ticket.ticket_id
  end

  test "another user cannot download the ticket", %{conn: conn} do
    owner = user_fixture()
    other = user_fixture()
    ticket = create_ticket(owner)

    conn =
      conn
      |> Plug.Test.init_test_session(%{user_id: other.id})
      |> get(~p"/user/tickets/#{ticket.ticket_id}/download")

    assert redirected_to(conn) == ~p"/dashboard"
  end

  test "guests are sent to login", %{conn: conn} do
    ticket = create_ticket(user_fixture())

    conn = get(conn, ~p"/user/tickets/#{ticket.ticket_id}/download")

    assert redirected_to(conn) == ~p"/user/login"
  end
end
