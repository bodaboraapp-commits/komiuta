defmodule Xpressbus.Hotels do
  @moduledoc """
  The Hotels context handles hotel management.
  """

  import Ecto.Query
  alias Xpressbus.{ContentCache, Repo}
  alias Xpressbus.Bookings.Hotel

  def list_hotels do
    Repo.all(Hotel)
  end

  def paginate_hotels(page, page_size) do
    from(h in Hotel,
      order_by: [asc: h.name],
      limit: ^page_size,
      offset: ^((page - 1) * page_size)
    )
    |> Repo.all()
  end

  def count_hotels do
    Repo.aggregate(Hotel, :count, :id)
  end

  def create_hotel(attrs) do
    result =
      %Hotel{}
      |> Hotel.changeset(attrs)
      |> Repo.insert()

    ContentCache.invalidate(Xpressbus.Chyllz)
    result
  end
end
