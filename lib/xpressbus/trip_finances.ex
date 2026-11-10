defmodule Xpressbus.TripFinances do
  @moduledoc """
  Per-trip budget and expense tracking for the itinerary management page.

  The same API backs both a booked bus trip (`{:ticket, ticket_id}`) and a saved
  Chyllz AI itinerary (`{:saved, saved_itinerary_id}`), so the management page
  works identically for either entry point. Everything is scoped to the owning
  user and persisted, so a budget or expense survives refreshes and devices.
  """

  import Ecto.Query

  alias Xpressbus.Repo
  alias Xpressbus.TripFinances.{TripBudget, TripExpense}

  @type scope :: %{
          required(:user_id) => String.t(),
          required(:ticket_id) => String.t() | nil,
          required(:saved_itinerary_id) => integer() | nil
        }

  @doc "Builds a finance scope for a user and a trip (`:ticket`) or itinerary (`:saved`)."
  def scope(%{id: user_id}, :ticket, ticket_id) do
    %{user_id: user_id, ticket_id: to_string(ticket_id), saved_itinerary_id: nil}
  end

  def scope(%{id: user_id}, :saved, saved_itinerary_id) do
    %{user_id: user_id, ticket_id: nil, saved_itinerary_id: saved_itinerary_id}
  end

  @doc "Current budget for the scope as a float (0.0 when not set)."
  def get_budget(%{user_id: _user_id} = scope) do
    case TripBudget |> scoped(scope) |> Repo.one() do
      nil -> 0.0
      %TripBudget{amount: amount} -> Decimal.to_float(amount)
    end
  end

  @doc "Creates or updates the budget for the scope."
  def set_budget(%{user_id: _user_id} = scope, amount) when is_number(amount) do
    attrs = %{
      user_id: scope.user_id,
      ticket_id: scope.ticket_id,
      saved_itinerary_id: scope.saved_itinerary_id,
      amount: amount
    }

    case TripBudget |> scoped(scope) |> Repo.one() do
      nil ->
        %TripBudget{}
        |> TripBudget.changeset(attrs)
        |> Repo.insert()
        |> wrap_budget()

      existing ->
        existing
        |> TripBudget.changeset(attrs)
        |> Repo.update()
        |> wrap_budget()
    end
  end

  def set_budget(_scope, _amount), do: {:error, :invalid_amount}

  @doc "Expenses for the scope, newest first, as display-ready maps."
  def list_expenses(%{user_id: _user_id} = scope) do
    TripExpense
    |> scoped(scope)
    |> order_by([expense], desc: expense.spent_on, desc: expense.id)
    |> Repo.all()
    |> Enum.map(&expense_row/1)
  end

  @doc "Persists a new expense for the scope."
  def add_expense(%{user_id: _user_id} = scope, attrs) do
    attrs =
      Map.merge(attrs, %{
        user_id: scope.user_id,
        ticket_id: scope.ticket_id,
        saved_itinerary_id: scope.saved_itinerary_id
      })

    %TripExpense{}
    |> TripExpense.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates one expense belonging to the scope."
  def update_expense(%{user_id: _user_id} = scope, id, attrs) do
    with {expense_id, ""} <- Integer.parse(to_string(id)),
         %TripExpense{} = expense <-
           TripExpense
           |> scoped(scope)
           |> where([expense], expense.id == ^expense_id)
           |> Repo.one() do
      expense
      |> TripExpense.changeset(attrs)
      |> Repo.update()
    else
      _other -> {:error, :not_found}
    end
  end

  @doc "Deletes one expense from the scope (never another user's row)."
  def delete_expense(%{user_id: _user_id} = scope, id) do
    with {expense_id, ""} <- Integer.parse(to_string(id)) do
      TripExpense
      |> scoped(scope)
      |> where([expense], expense.id == ^expense_id)
      |> Repo.delete_all()

      :ok
    else
      _other -> :ok
    end
  end

  defp scoped(query, %{user_id: user_id, ticket_id: nil, saved_itinerary_id: saved_itinerary_id})
       when not is_nil(saved_itinerary_id) do
    from(row in query,
      where:
        row.user_id == ^user_id and is_nil(row.ticket_id) and
          row.saved_itinerary_id == ^saved_itinerary_id
    )
  end

  defp scoped(query, %{user_id: user_id, ticket_id: ticket_id}) do
    from(row in query,
      where:
        row.user_id == ^user_id and row.ticket_id == ^ticket_id and is_nil(row.saved_itinerary_id)
    )
  end

  defp wrap_budget({:ok, %TripBudget{amount: amount}}), do: {:ok, Decimal.to_float(amount)}
  defp wrap_budget({:error, changeset}), do: {:error, changeset}

  defp expense_row(%TripExpense{} = expense) do
    %{
      id: expense.id,
      label: expense.label,
      category: expense.category || "Other",
      amount: Decimal.to_float(expense.amount),
      date: expense.spent_on
    }
  end
end
