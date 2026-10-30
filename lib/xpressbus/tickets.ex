defmodule Xpressbus.Tickets do
  @moduledoc """
  The Tickets context handles ticket tracking and searching.
  """

  import Ecto.Query
  alias Xpressbus.Repo
  alias Xpressbus.Tickets.Ticket

  @doc """
  Lists all tickets.
  """
  def list_tickets do
    Repo.all(Ticket)
  end

  @doc """
  Paginates tickets.
  """
  def paginate_tickets(page, page_size) do
    from(t in Ticket,
      order_by: [desc: t.inserted_at],
      limit: ^page_size,
      offset: ^((page - 1) * page_size)
    )
    |> Repo.all()
    |> Enum.map(&deserialize_seats/1)
  end

  @doc """
  Counts tickets per passenger phone for the given phone numbers.
  Returns a map of `%{phone => count}`.
  """
  def counts_by_passenger_phones(phones) when is_list(phones) do
    phones = phones |> Enum.reject(&is_nil/1) |> Enum.uniq()

    if phones == [] do
      %{}
    else
      from(t in Ticket,
        where: t.passenger_phone in ^phones,
        group_by: t.passenger_phone,
        select: {t.passenger_phone, count(t.id)}
      )
      |> Repo.all()
      |> Map.new()
    end
  end

  @doc """
  Counts total tickets.
  """
  def count_tickets do
    Repo.aggregate(Ticket, :count, :id)
  end

  @doc """
  Gets a single ticket by ticket_id.
  """
  def get_ticket!(ticket_id), do: Repo.get_by!(Ticket, ticket_id: ticket_id) |> deserialize_seats

  @doc """
  Gets a single ticket by ticket_id, returns nil if not found.
  """
  def get_ticket(ticket_id) do
    Repo.get_by(Ticket, ticket_id: ticket_id)
    |> Repo.preload(bus: [:bus_operator])
    |> deserialize_seats()
  end

  @doc """
  Searches tickets by ticket_id or passenger details.
  """
  def search_tickets(query) when is_binary(query) and byte_size(query) > 0 do
    pattern = "%#{query}%"

    from(t in Ticket,
      where:
        fragment("LOWER(?) LIKE LOWER(?)", t.ticket_id, ^pattern) or
          fragment("LOWER(?) LIKE LOWER(?)", t.passenger_name, ^pattern) or
          fragment("LOWER(?) LIKE LOWER(?)", t.passenger_phone, ^pattern)
    )
    |> Repo.all()
    |> Enum.map(&deserialize_seats/1)
  end

  def search_tickets(_), do: []

  @doc """
  Creates a ticket.
  """
  def create_ticket(attrs) do
    # ... logic ...
    attrs =
      for {k, v} <- attrs, into: %{} do
        {to_string(k), v}
      end
      |> serialize_seats()

    %Ticket{}
    |> Ticket.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a ticket.
  """
  def update_ticket(%Ticket{} = ticket, attrs) do
    ticket
    |> Ticket.changeset(attrs)
    |> Repo.update()
  end

  defp serialize_seats(attrs) when is_map(attrs) do
    # Handle both string and atom keys for "seats"
    seats = Map.get(attrs, "seats") || Map.get(attrs, :seats)

    cond do
      is_list(seats) ->
        encoded = Jason.encode!(seats)

        if Map.has_key?(attrs, "seats") or not Enum.any?(Map.keys(attrs), &is_atom/1) do
          # Use string key and ensure no mixed keys if possible (though cast will fail anyway if mixed)
          attrs |> Map.delete(:seats) |> Map.put("seats", encoded)
        else
          # Use atom key
          attrs |> Map.delete("seats") |> Map.put(:seats, encoded)
        end

      true ->
        attrs
    end
  end

  def deserialize_seats(%{seats: nil} = ticket), do: ticket

  def deserialize_seats(%{seats: seats} = ticket) when is_binary(seats) do
    case Jason.decode(seats) do
      {:ok, decoded} -> %{ticket | seats: decoded}
      _ -> ticket
    end
  end

  def deserialize_seats(ticket), do: ticket
end
