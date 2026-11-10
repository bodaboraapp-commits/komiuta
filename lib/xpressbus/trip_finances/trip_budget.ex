defmodule Xpressbus.TripFinances.TripBudget do
  use Ecto.Schema
  import Ecto.Changeset

  schema "trip_budgets" do
    field(:ticket_id, :string)
    field(:saved_itinerary_id, :integer)
    field(:amount, :decimal, default: Decimal.new("0"))

    belongs_to(:user, Xpressbus.Accounts.User, type: :binary_id)

    timestamps(type: :utc_datetime)
  end

  @fields ~w(user_id ticket_id saved_itinerary_id amount)a

  def changeset(trip_budget, attrs) do
    trip_budget
    |> cast(attrs, @fields)
    |> validate_required([:user_id, :amount])
    |> validate_number(:amount, greater_than_or_equal_to: 0)
    |> validate_scope()
  end

  defp validate_scope(changeset) do
    if get_field(changeset, :ticket_id) || get_field(changeset, :saved_itinerary_id) do
      changeset
    else
      add_error(changeset, :ticket_id, "a budget must belong to a trip or an itinerary")
    end
  end
end
