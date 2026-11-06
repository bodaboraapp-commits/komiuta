defmodule Xpressbus.Bookings.Pricing do
  @moduledoc """
  Single source of truth for checkout pricing.

  The amounts shown on the search card, seat map, passenger summary and payment
  page must all derive from the same base fare plus the platform convenience
  fee. The fee is a flat KES amount charged once per booking (not per seat).
  """

  @convenience_fee 50

  @doc "Flat convenience fee charged once per booking, in KES."
  def convenience_fee, do: @convenience_fee

  @doc """
  Calculates base fare, discount and final payable amount.

  Options:

    * `:booking?` - when false (no bus/seats selected) no convenience fee is
      charged. Defaults to `true`.
  """
  def calculate(base_fare, discount \\ 0, opts \\ []) do
    base = normalize_money(base_fare)
    discount = discount |> normalize_money() |> min(base)
    booking? = Keyword.get(opts, :booking?, true)

    fee = if booking? and base > 0, do: @convenience_fee, else: 0

    %{
      base_fare: base,
      discount: discount,
      convenience_fee: fee,
      final_price: max(0, base - discount) + fee
    }
  end

  @doc "Price for a seat class, falling back to the bus' normal fare."
  def price_for_type(bus, type) do
    normal = parse_price(Map.get(bus, :price), 1500)

    case type do
      :first_class -> parse_price(Map.get(bus, :first_class_price), normal)
      :vip -> parse_price(Map.get(bus, :vip_price), normal)
      :business -> parse_price(Map.get(bus, :business_price), normal)
      _ -> normal
    end
  end

  @doc "True when the operator actually sells one of the given seat classes."
  def seat_type_available?(bus, accepted) when is_list(accepted) do
    accepted = Enum.map(accepted, &String.downcase/1)

    bus
    |> Map.get(:seat_types, [])
    |> List.wrap()
    |> Enum.any?(fn seat_type ->
      String.downcase(to_string(seat_type)) in accepted
    end)
  end

  @doc "Parses a KES amount from an integer or a price string such as \"KSH 2,000\"."
  def parse_price(value, default \\ 0) do
    case value do
      nil ->
        default

      v when is_integer(v) ->
        v

      v when is_float(v) ->
        round(v)

      v when is_binary(v) ->
        numeric = String.replace(v, ~r/[^0-9.]/, "")

        case Float.parse(numeric) do
          {val, _} -> round(val)
          :error -> default
        end

      _ ->
        default
    end
  end

  defp normalize_money(value) when is_integer(value), do: max(0, value)
  defp normalize_money(value) when is_float(value), do: max(0, round(value))
  defp normalize_money(value), do: value |> parse_price(0) |> max(0)
end
