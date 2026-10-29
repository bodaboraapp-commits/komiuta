defmodule Xpressbus.HiddenGems do
  @moduledoc """
  The HiddenGems context handles hidden gem management.
  """

  import Ecto.Query
  alias Xpressbus.Repo
  alias Xpressbus.Bookings.HiddenGem

  def list_hidden_gems do
    Repo.all(HiddenGem)
  end

  def paginate_hidden_gems(page, page_size) do
    from(g in HiddenGem,
      order_by: [asc: g.title],
      limit: ^page_size,
      offset: ^((page - 1) * page_size)
    )
    |> Repo.all()
  end

  def count_hidden_gems do
    Repo.aggregate(HiddenGem, :count, :id)
  end

  def create_hidden_gem(attrs) do
    %HiddenGem{}
    |> HiddenGem.changeset(attrs)
    |> Repo.insert()
  end
end
