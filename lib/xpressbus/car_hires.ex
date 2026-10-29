defmodule Xpressbus.CarHires do
  @moduledoc """
  The CarHires context handles car hire management.
  """

  import Ecto.Query
  alias Xpressbus.Repo
  alias Xpressbus.Bookings.CarHire

  def list_car_hires do
    Repo.all(CarHire)
  end

  def paginate_car_hires(page, page_size) do
    from(c in CarHire,
      order_by: [asc: c.car_name],
      limit: ^page_size,
      offset: ^((page - 1) * page_size)
    )
    |> Repo.all()
  end

  def count_car_hires do
    Repo.aggregate(CarHire, :count, :id)
  end

  def create_car_hire(attrs) do
    %CarHire{}
    |> CarHire.changeset(attrs)
    |> Repo.insert()
  end
end
