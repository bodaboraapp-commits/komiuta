defmodule Xpressbus.TripFinances.TripExpense do
  use Ecto.Schema
  import Ecto.Changeset

  schema "trip_expenses" do
    field(:ticket_id, :string)
    field(:saved_itinerary_id, :integer)
    field(:label, :string)
    field(:category, :string, default: "Other")
    field(:amount, :decimal, default: Decimal.new("0"))
    field(:spent_on, :date)

    belongs_to(:user, Xpressbus.Accounts.User, type: :binary_id)

    timestamps(type: :utc_datetime)
  end

  @fields ~w(user_id ticket_id saved_itinerary_id label category amount spent_on)a

  def changeset(trip_expense, attrs) do
    trip_expense
    |> cast(attrs, @fields)
    |> validate_required([:user_id, :label, :category, :amount, :spent_on])
    |> validate_length(:label, max: 120)
    |> validate_number(:amount, greater_than_or_equal_to: 0)
    |> validate_scope()
  end

  defp validate_scope(changeset) do
    if get_field(changeset, :ticket_id) || get_field(changeset, :saved_itinerary_id) do
      changeset
    else
      add_error(changeset, :ticket_id, "an expense must belong to a trip or an itinerary")
    end
  end
end
