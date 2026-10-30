defmodule Xpressbus.TicketAccessTest do
  use ExUnit.Case, async: true

  alias Xpressbus.TicketAccess
  alias Xpressbus.Tickets.Ticket

  defp ticket(attrs \\ %{}) do
    struct(
      Ticket,
      Map.merge(
        %{ticket_id: "TKT-TOKEN1", passenger_phone: "0712345678"},
        attrs
      )
    )
  end

  test "tokens are valid for the ticket and phone they were generated for" do
    ticket = ticket()
    token = TicketAccess.token(ticket)

    assert TicketAccess.valid?(ticket, token)
    refute TicketAccess.valid?(ticket, "nope")
    refute TicketAccess.valid?(ticket, nil)
    refute TicketAccess.valid?(nil, token)
  end

  test "tokens do not validate across tickets" do
    first = ticket()
    second = ticket(%{ticket_id: "TKT-TOKEN2"})

    refute TicketAccess.valid?(second, TicketAccess.token(first))
  end

  test "normalize/1 compares the last 9 digits across formats" do
    assert TicketAccess.normalize("0712345678") == "712345678"
    assert TicketAccess.normalize("+254 712 345 678") == "712345678"
    assert TicketAccess.normalize("254712345678") == "712345678"
    assert TicketAccess.normalize(nil) == ""
  end

  test "path/1 never contains the phone number" do
    ticket = ticket()
    path = TicketAccess.path(ticket)

    assert path =~ "TKT-TOKEN1"
    assert path =~ "token="
    refute path =~ "0712345678"
  end
end
