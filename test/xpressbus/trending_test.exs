defmodule Xpressbus.TrendingTest do
  @moduledoc """
  The landing page shows little "recent booking" pills sourced from confirmed
  tickets in the database. They must be route-only (no passenger data), ordered
  by how many bookings a route has, and fall back to all-time popular routes
  when there is nothing recent.
  """

  use Xpressbus.DataCase, async: false

  import Ecto.Query

  alias Xpressbus.Repo
  alias Xpressbus.Tickets.Ticket
  alias Xpressbus.Trending

  defp ticket_fixture(attrs) do
    inserted_at = attrs[:inserted_at] || NaiveDateTime.utc_now()

    attrs =
      Map.merge(
        %{
          ticket_id: "TKT-TREND-#{System.unique_integer([:positive])}",
          from: "Nairobi",
          to: "Mombasa",
          travel_date: Date.utc_today(),
          departure: "7:00 AM",
          arrival: "3:00 PM",
          company: "Test Operator",
          price: "KES 1000",
          seats: "[\"1\"]",
          passenger_name: "Trend Test",
          passenger_phone: "0712345678",
          payment_method: "mpesa",
          status: "confirmed",
          type: "One Way"
        },
        Map.take(attrs, [:from, :to, :status])
      )

    ticket = Repo.insert!(struct(Ticket, attrs))
    set_inserted_at(ticket, inserted_at)
  end

  defp set_inserted_at(ticket, time) do
    time = NaiveDateTime.truncate(time, :second)
    Repo.update_all(from(t in Ticket, where: t.id == ^ticket.id), set: [inserted_at: time])
    %{ticket | inserted_at: time}
  end

  defp hours_ago(hours) do
    NaiveDateTime.add(NaiveDateTime.utc_now(), -hours * 3_600, :second)
  end

  test "returns live pills ordered by booking count for recent confirmed bookings" do
    for _ <- 1..3,
        do: ticket_fixture(%{from: "NAIROBI", to: "MOMBASA", inserted_at: hours_ago(1)})

    ticket_fixture(%{from: "Kisumu", to: "Nairobi", inserted_at: hours_ago(2)})

    # Not counted: unpaid booking and bookings outside the live window.
    ticket_fixture(%{from: "Nairobi", to: "Kisumu", status: "pending", inserted_at: hours_ago(1)})
    ticket_fixture(%{from: "Eldoret", to: "Nakuru", inserted_at: hours_ago(24 * 10)})

    pills = Trending.recent_booking_pills()

    assert length(pills) == 2

    [first, second] = pills
    assert first.from == "Nairobi"
    assert first.to == "Mombasa"
    assert first.count == 3
    assert first.live
    assert first.meta =~ "ago"

    assert second.from == "Kisumu"
    assert second.to == "Nairobi"
    assert second.count == 1
    assert second.live
  end

  test "falls back to popular routes when nothing was booked in the live window" do
    for _ <- 1..2,
        do: ticket_fixture(%{from: "MOMBASA", to: "NAIROBI", inserted_at: hours_ago(24 * 10)})

    ticket_fixture(%{from: "Nairobi", to: "Kisumu", inserted_at: hours_ago(24 * 12)})

    [first | _rest] = pills = Trending.recent_booking_pills()

    assert first.from == "Mombasa"
    assert first.to == "Nairobi"
    assert first.count == 2
    refute first.live
    assert first.meta == "2 booked"
    assert Enum.all?(pills, &(!&1.live))
  end

  test "returns no pills when there are no confirmed bookings" do
    ticket_fixture(%{from: "Nairobi", to: "Mombasa", status: "pending"})
    assert Trending.recent_booking_pills() == []
  end

  test "respects the limit option" do
    for city <- ~w(Kisumu Nakuru Eldoret Kisii) do
      ticket_fixture(%{from: city, to: "Nairobi", inserted_at: hours_ago(1)})
    end

    assert length(Trending.recent_booking_pills(limit: 2)) == 2
  end

  test "relative_time renders human readable ages" do
    now = NaiveDateTime.utc_now()

    assert Trending.relative_time(NaiveDateTime.add(now, -20, :second)) == "just now"
    assert Trending.relative_time(NaiveDateTime.add(now, -5 * 60, :second)) == "5m ago"
    assert Trending.relative_time(NaiveDateTime.add(now, -3 * 3_600, :second)) == "3h ago"
    assert Trending.relative_time(NaiveDateTime.add(now, -2 * 86_400, :second)) == "2d ago"
  end
end
