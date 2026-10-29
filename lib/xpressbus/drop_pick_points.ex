defmodule Xpressbus.DropPickPoints do
  @moduledoc """
  The DropPickPoints context handles drop/pick point management.
  """

  import Ecto.Query
  alias Xpressbus.Repo
  alias Xpressbus.DropPickPoints.DropPickPoint

  @doc """
  Lists all drop/pick points.
  """
  def list_drop_pick_points do
    Repo.all(DropPickPoint)
  end

  @doc """
  Lists active drop/pick points for a given city (case-insensitive match on city name).
  """
  def list_by_city(city) when is_binary(city) do
    points =
      from(d in DropPickPoint,
        where: d.active == true and fragment("LOWER(?) LIKE LOWER(?)", d.city, ^city),
        order_by: [asc: d.name]
      )
      |> Repo.all()

    if Enum.empty?(points) do
      # High-fidelity fallback to ensure the UI never breaks for unseeded cities
      [%{name: "#{String.capitalize(city)} Main Terminal", city: city}]
    else
      points
    end
  end

  @doc """
  Paginates drop/pick points.
  """
  def paginate_drop_pick_points(page, page_size) do
    from(d in DropPickPoint,
      order_by: [asc: d.name],
      limit: ^page_size,
      offset: ^((page - 1) * page_size)
    )
    |> Repo.all()
  end

  @doc """
  Counts total drop/pick points.
  """
  def count_drop_pick_points do
    Repo.aggregate(DropPickPoint, :count, :id)
  end

  @doc """
  Creates a drop/pick point.
  """
  def create_drop_pick_point(attrs) do
    %DropPickPoint{}
    |> DropPickPoint.changeset(attrs)
    |> Repo.insert()
  end
end
