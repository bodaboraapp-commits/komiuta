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
    assert pdf =~ "MOMBASA"
    assert pdf =~ "NAIROBI"
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

  test "embeds the boarding QR code and Code 128 barcode as vectors" do
    pdf = TicketPDF.render(ticket())

    assert pdf =~ "BOARDING CODES"
    assert pdf =~ "SCAN TO BOARD"
    assert pdf =~ "CODE 128"
    # The codes are drawn as filled vector rectangles, so the PDF needs no
    # embedded images and stays sharp when printed.
    refute pdf =~ "/Subtype /Image"

    rectangle_count = Regex.scan(~r/\d+ \d+ \d+ \d+ re\n/, pdf) |> length()
    assert rectangle_count > 300
  end

  test "xref offsets point at the objects they describe" do
    pdf = TicketPDF.render(ticket())

    [_, after_marker] = String.split(pdf, "xref\n0 ", parts: 2)
    {newline_index, 1} = :binary.match(after_marker, "\n")
    {count_string, rest} = String.split_at(after_marker, newline_index)
    count = count_string |> String.trim() |> String.to_integer()
    assert count >= 7

    offsets =
      rest
      |> String.split("\n", trim: true)
      |> Enum.drop(1)
      |> Enum.take(count - 1)
      |> Enum.map(fn line -> line |> String.split(" ") |> hd() |> String.to_integer() end)

    assert length(offsets) == count - 1

    offsets
    |> Enum.with_index(1)
    |> Enum.each(fn {offset, number} ->
      object_header = "#{number} 0 obj"
      assert binary_part(pdf, offset, byte_size(object_header)) == object_header
    end)
  end
end
