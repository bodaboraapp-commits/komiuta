defmodule Xpressbus.Routes do
  @moduledoc """
  The Routes context handles route lookup and origin/destination enumeration
  for the booking search experience.
  """

  import Ecto.Query
  alias Xpressbus.Repo
  alias Xpressbus.Routes.Route

  @doc """
  Returns the list of distinct origin and destination city names that appear
  in any active route. The result is a sorted, deduplicated list of strings.
  """
  def list_active_route_locations do
    origins =
      from(r in Route,
        where: r.active == true and not is_nil(r.origin),
        select: r.origin,
        distinct: true
      )
      |> Repo.all()

    destinations =
      from(r in Route,
        where: r.active == true and not is_nil(r.destination),
        select: r.destination,
        distinct: true
      )
      |> Repo.all()

    (origins ++ destinations)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Returns the total number of routes.
  """
  def count_routes do
    Repo.aggregate(Route, :count, :id)
  end

  @doc """
  Returns a paginated list of routes ordered by id ascending.
  """
  def paginate_routes(page, page_size) do
    from(r in Route,
      order_by: [asc: r.id],
      limit: ^page_size,
      offset: ^((page - 1) * page_size)
    )
    |> Repo.all()
  end

  @doc """
  Ensures a route exists in the database.
  """
  def ensure_route(origin, destination) do
    case Repo.get_by(Route, origin: origin, destination: destination) do
      nil ->
        %Route{}
        |> Route.changeset(%{origin: origin, destination: destination, active: true})
        |> Repo.insert()

      route ->
        {:ok, route}
    end
  end
end
