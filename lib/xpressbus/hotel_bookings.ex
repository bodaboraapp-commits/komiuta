defmodule Xpressbus.HotelBookings do
  @moduledoc """
  Hotel / accommodation reservations made through Chyllz.

  A reservation snapshots the hotel name, location and nightly price at booking
  time, so it stays readable even if the catalogue entry changes or is removed.
  """

  import Ecto.Query

  alias Xpressbus.Bookings.Hotel
  alias Xpressbus.Bookings.HotelBooking
  alias Xpressbus.Repo

  @doc """
  Creates a reservation request for a signed-in user.

  `attrs` must include `check_in`, `check_out`, `rooms` and `guests`; guest
  contact details default to the account profile.
  """
  def create_booking(user, %Hotel{} = hotel, attrs) do
    with {:ok, check_in} <- parse_date(fetch(attrs, :check_in)),
         {:ok, check_out} <- parse_date(fetch(attrs, :check_out)),
         :ok <- validate_dates(check_in, check_out) do
      rooms = positive_int(fetch(attrs, :rooms), 1)
      guests = positive_int(fetch(attrs, :guests), 1)
      nights = Date.diff(check_out, check_in)
      price = hotel.price_per_night || Decimal.new("0")
      total = price |> Decimal.mult(rooms) |> Decimal.mult(nights) |> Decimal.round(2)

      %HotelBooking{}
      |> HotelBooking.changeset(%{
        reference: new_reference(),
        hotel_id: hotel.id,
        hotel_name: hotel.name,
        hotel_location: hotel.location,
        user_id: user.id,
        guest_name: blank_to(fetch(attrs, :guest_name), user.name),
        guest_phone: blank_to(fetch(attrs, :guest_phone), user.phone),
        guest_email: blank_to(fetch(attrs, :guest_email), user.email),
        check_in: check_in,
        check_out: check_out,
        nights: nights,
        rooms: rooms,
        guests: guests,
        price_per_night: price,
        total_amount: total,
        status: "pending",
        notes: blank_to(fetch(attrs, :notes), nil)
      })
      |> Repo.insert()
    end
  end

  @doc "All accommodation bookings for one account, newest stay first."
  def list_for_user(user_id) do
    from(b in HotelBooking,
      where: b.user_id == ^user_id,
      order_by: [desc: b.check_in, desc: b.inserted_at],
      preload: [:hotel]
    )
    |> Repo.all()
  end

  def count_for_user(user_id) do
    from(b in HotelBooking, where: b.user_id == ^user_id)
    |> Repo.aggregate(:count, :id)
  end

  def get_for_user(user_id, reference) do
    Repo.one(
      from(b in HotelBooking,
        where: b.user_id == ^user_id and b.reference == ^reference,
        preload: [:hotel]
      )
    )
  end

  defp parse_date(%Date{} = date), do: {:ok, date}

  defp parse_date(value) when is_binary(value) and value != "" do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      _ -> :error
    end
  end

  defp parse_date(_), do: :error

  defp validate_dates(check_in, check_out) do
    cond do
      Date.compare(check_in, Date.utc_today()) == :lt -> {:error, :past_check_in}
      Date.compare(check_out, check_in) != :gt -> {:error, :invalid_dates}
      true -> :ok
    end
  end

  defp positive_int(value, _fallback) when is_integer(value), do: max(value, 1)

  defp positive_int(value, fallback) when is_binary(value) do
    case Integer.parse(value) do
      {number, _} when number > 0 -> number
      _ -> fallback
    end
  end

  defp positive_int(_value, fallback), do: fallback

  defp fetch(attrs, key) do
    Map.get(attrs, key) || Map.get(attrs, to_string(key))
  end

  defp blank_to(value, fallback) when is_binary(value) do
    case String.trim(value) do
      "" -> fallback
      trimmed -> trimmed
    end
  end

  defp blank_to(_value, fallback), do: fallback

  defp new_reference do
    "STAY-" <> Base.encode16(:crypto.strong_rand_bytes(4), case: :upper)
  end
end
