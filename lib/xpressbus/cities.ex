defmodule Xpressbus.Cities do
  @moduledoc """
  The Cities context handles city management.
  """

  import Ecto.Query
  alias Xpressbus.Repo
  alias Xpressbus.Cities.City

  @doc """
  Lists all cities.
  """
  def list_cities do
    Repo.all(City)
  end

  @doc """
  Paginates cities.
  """
  def paginate_cities(page, page_size) do
    from(c in City,
      order_by: [asc: c.name],
      limit: ^page_size,
      offset: ^((page - 1) * page_size)
    )
    |> Repo.all()
  end

  @doc """
  Counts total cities.
  """
  def count_cities do
    Repo.aggregate(City, :count, :id)
  end

  @doc """
  Creates a city.
  """
  def create_city(attrs) do
    %City{}
    |> City.changeset(attrs)
    |> Repo.insert()
  end
end
