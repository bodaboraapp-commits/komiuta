defmodule Xpressbus.TravelAssistant.Money do
  @moduledoc """
  Money/percentage formatting shared by the assistant engine.

  The public web formatters live in `XpressbusWeb.Format`; the assistant runs in
  the context layer (and in tests without a web request), so it keeps a tiny,
  dependency-free formatter here instead of reaching into the web namespace.
  """

  @doc "Formats a Decimal, integer or numeric string as grouped text."
  def format(nil), do: "—"

  def format(value) do
    decimal = to_decimal(value) |> Decimal.round(2)
    integer = Decimal.round(decimal, 0, :down)

    if Decimal.equal?(decimal, integer) do
      decimal |> Decimal.to_integer() |> group()
    else
      cents =
        decimal
        |> Decimal.sub(integer)
        |> Decimal.abs()
        |> Decimal.mult(100)
        |> Decimal.round(0)
        |> Decimal.to_integer()
        |> Integer.to_string()
        |> String.pad_leading(2, "0")

      group(Decimal.to_integer(integer)) <> "." <> cents
    end
  end

  @doc "Formats a value with a currency code, e.g. `KES 12,500`."
  def format_with_code(nil, _code), do: "—"
  def format_with_code(value, code), do: "#{code} #{format(value)}"

  @doc "Turns a user amount string into a non-negative Decimal."
  def to_decimal(nil), do: Decimal.new(0)
  def to_decimal(%Decimal{} = value), do: value
  def to_decimal(value) when is_integer(value), do: Decimal.new(value)
  def to_decimal(value) when is_float(value), do: Decimal.from_float(value)

  def to_decimal(value) when is_binary(value) do
    cleaned = String.replace(value, ~r/[^0-9.\-]/, "")

    case Decimal.parse(cleaned) do
      {decimal, ""} -> decimal
      _other -> Decimal.new(0)
    end
  end

  def to_decimal(_value), do: Decimal.new(0)

  @doc "Percentage of `part` in `whole`, rounded to a whole number, or 0."
  def percent(_part, whole) when is_nil(whole), do: 0

  def percent(part, whole) do
    whole = to_decimal(whole)

    if Decimal.equal?(whole, 0) do
      0
    else
      part
      |> to_decimal()
      |> Decimal.div(whole)
      |> Decimal.mult(100)
      |> Decimal.round(0)
      |> Decimal.to_integer()
    end
  end

  defp group(integer) when integer < 0, do: "-" <> group(-integer)

  defp group(integer) do
    integer
    |> Integer.to_string()
    |> do_group()
  end

  defp do_group(digits) when byte_size(digits) <= 3, do: digits

  defp do_group(digits) do
    size = byte_size(digits)
    prefix = binary_part(digits, 0, size - 3)
    last = binary_part(digits, size - 3, 3)
    do_group(prefix) <> "," <> last
  end
end
