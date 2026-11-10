defmodule XpressbusWeb.RecentBookingsPillsTest do
  @moduledoc """
  The landing page renders database-driven "recent booking" pills directly
  above the trusted-operators marquee, inside a container that never grows
  wider than the search pill.
  """

  use XpressbusWeb.ConnCase, async: false

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias Xpressbus.Repo
  alias Xpressbus.Tickets.Ticket

  defp recent_booking(from, to) do
    ticket =
      Repo.insert!(%Ticket{
        ticket_id: "TKT-PILL-#{System.unique_integer([:positive])}",
        from: from,
        to: to,
        travel_date: Date.utc_today(),
        departure: "7:00 AM",
        arrival: "3:00 PM",
        company: "Test Operator",
        price: "KES 1000",
        seats: "[\"1\"]",
        passenger_name: "Pill Test",
        passenger_phone: "0712345678",
        payment_method: "mpesa",
        status: "confirmed",
        type: "One Way"
      })

    Repo.update_all(from(t in Ticket, where: t.id == ^ticket.id),
      set: [inserted_at: NaiveDateTime.add(NaiveDateTime.utc_now(), -120, :second)]
    )
  end

  test "renders live booking pills before the trusted operators section", %{conn: conn} do
    recent_booking("NAIROBI", "MOMBASA")
    recent_booking("NAIROBI", "MOMBASA")
    recent_booking("KISUMU", "NAIROBI")

    {:ok, view, _html} = live(conn, "/")

    assert has_element?(view, "#recent-bookings-pills")
    assert has_element?(view, "#recent-booking-Nairobi-Mombasa")

    html = render(view)
    assert html =~ "Live bookings"
    assert html =~ "Nairobi"
    assert html =~ "Mombasa"

    # Same width budget as the search pill; the row is centred and wraps into
    # centred lines instead of stretching the page.
    pills_html = view |> element("#recent-bookings-pills") |> render()
    assert pills_html =~ "max-w-[1350px]"
    assert pills_html =~ "flex-wrap"
    assert pills_html =~ "justify-center"

    # The partners/benefits block sits close to the pills row and to the
    # "#1 Choice" heading (reduced whitespace).
    assert html =~ "pt-8 pb-10 md:pt-10 md:pb-12"
    assert html =~ "mb-6 md:mb-8"
    assert html =~ "px-6 pt-4 md:pt-5"

    # The pills are outside the search form.
    refute has_element?(view, "#search-form #recent-bookings-pills")
  end

  test "hides the pills row when there are no confirmed bookings", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")

    refute has_element?(view, "#recent-bookings-pills")
  end
end
