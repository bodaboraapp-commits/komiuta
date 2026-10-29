defmodule Xpressbus.Events do
  @moduledoc """
  The Events context handles event management.
  """

  import Ecto.Query
  alias Xpressbus.Repo
  alias Xpressbus.Bookings.Event

  def list_events do
    Repo.all(Event)
  end

  def paginate_events(page, page_size) do
    from(e in Event,
      order_by: [desc: e.date],
      limit: ^page_size,
      offset: ^((page - 1) * page_size)
    )
    |> Repo.all()
  end

  def count_events do
    Repo.aggregate(Event, :count, :id)
  end

  def create_event(attrs) do
    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
  end
end
