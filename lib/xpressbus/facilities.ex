defmodule Xpressbus.Facilities do
  @moduledoc """
  The Facilities context handles facility management.
  """

  import Ecto.Query
  alias Xpressbus.Repo
  alias Xpressbus.Facilities.Facility

  @doc """
  Lists all facilities.
  """
  def list_facilities do
    Repo.all(Facility)
  end

  @doc """
  Paginates facilities.
  """
  def paginate_facilities(page, page_size) do
    from(f in Facility,
      order_by: [asc: f.name],
      limit: ^page_size,
      offset: ^((page - 1) * page_size)
    )
    |> Repo.all()
  end

  @doc """
  Counts total facilities.
  """
  def count_facilities do
    Repo.aggregate(Facility, :count, :id)
  end

  @doc """
  Creates a facility.
  """
  def create_facility(attrs) do
    %Facility{}
    |> Facility.changeset(attrs)
    |> Repo.insert()
  end
end
