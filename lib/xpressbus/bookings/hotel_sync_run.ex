defmodule Xpressbus.Bookings.HotelSyncRun do
  use Ecto.Schema
  import Ecto.Changeset

  schema "hotel_sync_runs" do
    field(:status, :string)
    field(:hotels_count, :integer, default: 0)
    field(:matched_count, :integer, default: 0)
    field(:details, :string)

    timestamps(type: :utc_datetime)
  end

  def changeset(run, attrs) do
    run
    |> cast(attrs, [:status, :hotels_count, :matched_count, :details])
    |> validate_required([:status])
    |> validate_inclusion(:status, ~w(success partial failed))
  end
end
