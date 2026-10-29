defmodule Xpressbus.Buses do
  @moduledoc """
  The Buses context.
  """

  import Ecto.Query, warn: false
  alias Xpressbus.Repo
  alias Xpressbus.Bookings.Bus

  @doc """
  Returns the list of buses.
  """
  def list_buses do
    Repo.all(Bus) |> Repo.preload([:bus_operator])
  end

  @doc """
  Paginates buses.
  """
  def paginate_buses(page, page_size) do
    from(b in Bus,
      order_by: [desc: b.inserted_at],
      limit: ^page_size,
      offset: ^((page - 1) * page_size)
    )
    |> Repo.all()
    |> Repo.preload([:bus_operator])
  end

  @doc """
  Counts total buses.
  """
  def count_buses do
    Repo.aggregate(Bus, :count, :id)
  end

  @doc """
  Gets a single bus.
  """
  def get_bus!(id), do: Repo.get!(Bus, id) |> Repo.preload([:bus_operator])

  @doc """
  Creates a bus.
  """
  def create_bus(attrs \\ %{}) do
    %Bus{}
    |> Bus.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a bus.
  """
  def update_bus(%Bus{} = bus, attrs) do
    bus
    |> Bus.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a bus.
  """
  def delete_bus(%Bus{} = bus) do
    Repo.delete(bus)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking bus changes.
  """
  def change_bus(%Bus{} = bus, attrs \\ %{}) do
    Bus.changeset(bus, attrs)
  end
end
