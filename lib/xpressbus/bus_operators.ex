defmodule Xpressbus.BusOperators do
  @moduledoc """
  The BusOperators context handles bus operator management.
  """

  import Ecto.Query
  alias Xpressbus.Repo
  alias Xpressbus.BusOperators.BusOperator

  @doc """
  Lists all active bus operators.
  """
  def list_active_bus_operators do
    from(b in BusOperator, where: b.active == true, order_by: [asc: b.name])
    |> Repo.all()
  end

  @doc """
  Lists all bus operators.
  """
  def list_bus_operators do
    Repo.all(BusOperator)
  end

  @doc """
  Paginates bus operators.
  """
  def paginate_bus_operators(page, page_size) do
    from(b in BusOperator,
      order_by: [asc: b.name],
      limit: ^page_size,
      offset: ^((page - 1) * page_size)
    )
    |> Repo.all()
  end

  @doc """
  Counts total bus operators.
  """
  def count_bus_operators do
    Repo.aggregate(BusOperator, :count, :id)
  end

  @doc """
  Creates or updates a bus operator by name.
  """
  def upsert_bus_operator(attrs) do
    case Repo.get_by(BusOperator, name: attrs.name) do
      nil ->
        %BusOperator{}
        |> BusOperator.changeset(attrs)
        |> Repo.insert()

      operator ->
        operator
        |> BusOperator.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Creates a bus operator.
  """
  def create_bus_operator(attrs) do
    %BusOperator{}
    |> BusOperator.changeset(attrs)
    |> Repo.insert()
  end
end
