defmodule Xpressbus.Repo.Migrations.IncludeRegistrationInBusUniqueKey do
  use Ecto.Migration

  @moduledoc """
  Two real trips can leave at the same time from the same operator (BuuPass
  itself lists e.g. two Greenline shuttles at 9:30 PM and two at 10:00 PM on
  Nairobi -> Kisumu). The old key collapsed them into one row.

  Include the provider/bus registration (BuuPass trip id) so distinct trips at
  the same departure time can coexist.
  """

  def up do
    drop unique_index(:buses, [:company, :departure, :from, :to, :travel_date],
           name: :unique_bus_trip
         )

    create unique_index(
             :buses,
             [:company, :registration, :from, :to, :travel_date],
             name: :unique_bus_trip
           )
  end

  def down do
    drop unique_index(:buses, [:company, :registration, :from, :to, :travel_date],
           name: :unique_bus_trip
         )

    create unique_index(
             :buses,
             [:company, :departure, :from, :to, :travel_date],
             name: :unique_bus_trip
           )
  end
end
