defmodule XpressbusWeb.Operators do
  @moduledoc """
  Read-only operator pages and the route/city cross-links around them.

  Operators are derived from the live `buses.company` data, so every operator
  page reflects real routes and fares rather than hand-maintained lists.
  """

  import Ecto.Query

  alias Xpressbus.Bookings.Bus
  alias Xpressbus.Repo

  def slug(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  def top(limit \\ 20) do
    Repo.all(
      from(b in Bus,
        where: not is_nil(b.company),
        group_by: b.company,
        select: %{name: b.company, buses: count(b.id)},
        order_by: [desc: count(b.id)],
        limit: ^limit
      )
    )
  end

  def find(slug) do
    top(500)
    |> Enum.find(&(slug(&1.name) == slug))
  end

  def routes(name) do
    Repo.all(
      from(b in Bus,
        where: b.company == ^name,
        order_by: [asc: b.travel_date],
        limit: 600
      )
    )
    |> Enum.group_by(&{&1.from, &1.to})
    |> Enum.map(fn {{from, to}, buses} ->
      prices =
        buses
        |> Enum.map(&parse_price(&1.price))
        |> Enum.reject(&is_nil/1)

      ratings =
        buses
        |> Enum.map(&parse_rating(&1.rating))
        |> Enum.reject(&is_nil/1)

      %{
        from: from,
        to: to,
        count: length(buses),
        min_price: Enum.min(prices, fn -> nil end),
        rating: average(ratings)
      }
    end)
    |> Enum.sort_by(&(-&1.count))
    |> Enum.take(20)
  end

  def cities(name) do
    Repo.all(from(b in Bus, where: b.company == ^name, select: b.from, distinct: true))
    |> Enum.reject(&is_nil/1)
    |> Enum.sort()
  end

  def average([]), do: nil
  def average(values), do: Float.round(Enum.sum(values) / length(values), 1)

  defp parse_price(value) when is_binary(value) do
    case Integer.parse(String.replace(value, ~r/[^0-9]/, "")) do
      {price, _} when price > 0 -> price
      _ -> nil
    end
  end

  defp parse_price(_), do: nil

  defp parse_rating(value) when is_binary(value) do
    case Float.parse(value) do
      {rating, _} -> rating
      _ -> nil
    end
  end

  defp parse_rating(_), do: nil
end
