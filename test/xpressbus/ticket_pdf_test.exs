defmodule Xpressbus.TicketPDFTest do
  use ExUnit.Case, async: true

  alias Xpressbus.TicketPDF
  alias Xpressbus.Tickets.Ticket

  defp ticket(overrides \\ %{}) do
    struct(
      %Ticket{
        ticket_id: "TKT-ABC123",
        from: "Mombasa",
        to: "Nairobi",
        travel_date: ~D[2026-10-29],
        departure: "7:00 AM",
        arrival: "5:30 PM",
        company: "MashPoa",
        price: "KSH 2300",
        seats: "[\"6\"]",
        passenger_name: "Test User",
        passenger_phone: "0798335246",
        payment_method: "mpesa",
        status: "confirmed",
        type: "One Way"
      },
      overrides
    )
  end

  test "renders a valid single-page PDF with the ticket details" do
    pdf = TicketPDF.render(ticket())

    assert String.starts_with?(pdf, "%PDF-1.4")
    assert String.trim_trailing(pdf) |> String.ends_with?("%%EOF")
    assert pdf =~ ~r/xref\n0 \d+/
    assert pdf =~ "startxref"
    assert pdf =~ "TKT-ABC123"
    assert pdf =~ "Mombasa"
    assert pdf =~ "Nairobi"
    assert pdf =~ "MashPoa"
    assert pdf =~ "6"
  end

  test "escapes parentheses and strips non-ASCII characters" do
    pdf =
      TicketPDF.render(ticket(%{passenger_name: "Test (User) — Café", from: "Nai\\robi"}))

    refute pdf =~ "—"
    assert pdf =~ "Test \\(User\\)"
  end

  test "handles missing optional values" do
    pdf = TicketPDF.render(ticket(%{passenger_name: nil, seats: nil, travel_date: nil}))
    assert String.starts_with?(pdf, "%PDF-1.4")
  end
end
