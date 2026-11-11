defmodule Xpressbus.CarHires do
  @moduledoc """
  The CarHires context handles car hire management.

  Car hire rows power the public Chyllz "Premium Car Hire" section; only active
  rows are shown there. Admin changes made here are database-backed and appear on
  the website immediately.
  """

  import Ecto.Query

  alias Xpressbus.Bookings.CarHire
  alias Xpressbus.{ContentCache, Repo}

  @doc "Lists every car hire row, including inactive rows."
  def list_car_hires do
    Repo.all(from(c in CarHire, order_by: [asc: c.car_name, asc: c.location]))
  end

  @doc "Lists active car hire rows for the public car hire section."
  def list_active_car_hires do
    Repo.all(from(c in CarHire, where: c.active == true, order_by: [asc: c.price_per_day]))
  end

  @doc """
  Paginates car hire rows for the admin screen.

  Returns `{cars, total_count}`. An optional search term matches car name, type
  or location.
  """
  def paginate_car_hires(page, page_size, search \\ "") do
    query = filtered_query(search)

    total = Repo.aggregate(query, :count, :id)

    cars =
      query
      |> order_by([c], asc: c.car_name, asc: c.location)
      |> limit(^page_size)
      |> offset(^((page - 1) * page_size))
      |> Repo.all()

    {cars, total}
  end

  def count_car_hires, do: Repo.aggregate(CarHire, :count, :id)

  def count_car_hires(search) when is_binary(search) do
    search
    |> filtered_query()
    |> Repo.aggregate(:count, :id)
  end

  def get_car_hire(id), do: Repo.get(CarHire, id)
  def get_car_hire!(id), do: Repo.get!(CarHire, id)

  def create_car_hire(attrs) do
    result =
      %CarHire{}
      |> CarHire.changeset(attrs)
      |> Repo.insert()

    ContentCache.invalidate(Xpressbus.Chyllz)
    result
  end

  def update_car_hire(%CarHire{} = car_hire, attrs) do
    result = car_hire |> CarHire.changeset(attrs) |> Repo.update()
    ContentCache.invalidate(Xpressbus.Chyllz)
    result
  end

  def delete_car_hire(%CarHire{} = car_hire) do
    result = Repo.delete(car_hire)
    ContentCache.invalidate(Xpressbus.Chyllz)
    result
  end

  @doc "Flips a car hire between active and inactive immediately."
  def toggle_active(%CarHire{} = car_hire) do
    update_car_hire(car_hire, %{active: !car_hire.active})
  end

  defp filtered_query(search) do
    search = String.trim(to_string(search || ""))
    pattern = "%#{search}%"

    query = from(c in CarHire)

    if search == "" do
      query
    else
      where(
        query,
        [c],
        fragment("LOWER(?) LIKE LOWER(?)", c.car_name, ^pattern) or
          fragment("LOWER(?) LIKE LOWER(?)", c.type, ^pattern) or
          fragment("LOWER(?) LIKE LOWER(?)", c.location, ^pattern)
      )
    end
  end
end
