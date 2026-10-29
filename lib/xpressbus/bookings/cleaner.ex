defmodule Xpressbus.Bookings.Cleaner do
  alias Xpressbus.Bookings.Bus
  alias Xpressbus.Tickets.Ticket
  alias Xpressbus.Repo
  import Ecto.Query
  require Logger

  @doc """
  Removes stale bus records from the database.

  A bus is considered stale when:
  - Its travel_date is in the past, OR
  - All seats are occupied (completely booked)

  Buses with at least one platform booking (ticket) are preserved
  regardless of staleness so user booking history remains intact.
  """
  def clean_stale_buses do
    today = Date.utc_today()

    booked_bus_ids = from(t in Ticket, select: t.bus_id)

    stale_query =
      from(b in Bus,
        where: b.id not in subquery(booked_bus_ids),
        where:
          b.travel_date < ^today or fragment("JSON_LENGTH(?)", b.occupied_seats) >= b.total_seats
      )

    {count, _} = Repo.delete_all(stale_query)

    if count > 0 do
      Logger.info(
        "🧹 Cleaned #{count} stale bus(es) with past travel dates or fully booked seats."
      )
    else
      Logger.info("✨ No stale buses to clean.")
    end

    count
  end
end
