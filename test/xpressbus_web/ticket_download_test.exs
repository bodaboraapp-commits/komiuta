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

  test "the downloaded PDF is a printable boarding pass with boarding codes", %{conn: conn} do
    user = user_fixture()
    ticket = create_ticket(user)

    conn =
      conn
      |> Plug.Test.init_test_session(%{user_id: user.id})
      |> get(~p"/user/tickets/#{ticket.ticket_id}/download")

    pdf = response(conn, 200)

    assert pdf =~ "%PDF-1.4"
    assert pdf =~ "BOARDING CODES"
    assert pdf =~ "SCAN TO BOARD"
    assert pdf =~ "CODE 128"
    assert pdf =~ ticket.ticket_id
    assert length(Regex.scan(~r/\d+ \d+ \d+ \d+ re\n/, pdf)) > 300
  end

  test "the signed ticket token downloads the PDF without signing in", %{conn: conn} do
    ticket = create_ticket(user_fixture())

    conn = get(conn, Xpressbus.TicketAccess.download_path(ticket))

    pdf = response(conn, 200)
    assert get_resp_header(conn, "content-type") |> hd() =~ "application/pdf"
    assert get_resp_header(conn, "content-disposition") |> hd() =~ ticket.ticket_id
    assert pdf =~ "SCAN TO BOARD"
  end

  test "a tampered token cannot download the ticket", %{conn: conn} do
    ticket = create_ticket(user_fixture())

    conn = get(conn, Xpressbus.TicketAccess.download_path(ticket) <> "tampered")

    assert redirected_to(conn) == ~p"/user/login"
    refute conn.resp_body =~ "%PDF-1.4"
  end

  test "guests without a token cannot use the public download path", %{conn: conn} do
    ticket = create_ticket(user_fixture())

    conn = get(conn, ~p"/tickets/#{ticket.ticket_id}/download")

    assert redirected_to(conn) == ~p"/user/login"
    refute conn.resp_body =~ "%PDF-1.4"
  end
end
