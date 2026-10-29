defmodule XpressbusWeb.Format do
  @moduledoc """
  Presentation helpers shared by the public catalogue and insurance pages.

  Catalogue prices are stored as `Decimal` values, so templates need a single
  place that turns them into consistent, human readable strings (thousands
  separators, no floating point noise). Keeping the helpers here also means
  the Chyllz and InSURE pages cannot drift apart visually.
  """

  @doc """
  Formats a money amount for display.

  Accepts a `Decimal`, an integer, a float or a numeric string and returns a
  grouped string without a currency symbol, e.g. `Decimal.new("12500")` becomes
  `"12,500"`. Cents are preserved when present (`"1,234.50"`). `nil` renders as
  an em dash so missing data never crashes a card.
  """
  def money(nil), do: "—"

  def money(value) do
    decimal = value |> to_decimal() |> Decimal.round(2)
    integer_part = Decimal.round(decimal, 0, :down)

    if Decimal.equal?(decimal, integer_part) do
      integer_part
      |> Decimal.to_integer()
      |> group_digits()
    else
      cents =
        decimal
        |> Decimal.sub(integer_part)
        |> Decimal.abs()
        |> Decimal.mult(100)
        |> Decimal.round(0)
        |> Decimal.to_integer()
        |> Integer.to_string()
        |> String.pad_leading(2, "0")

      integer_part
      |> Decimal.to_integer()
      |> group_digits()
      |> Kernel.<>(".")
      |> Kernel.<>(cents)
    end
  end

  @doc """
  Formats a rating for display, rounded to one decimal place.

  Ratings are stored as `Decimal` values; `nil` renders as an em dash.
  """
  def rating(nil), do: "—"

  def rating(value) do
    value
    |> to_decimal()
    |> Decimal.round(1)
    |> Decimal.to_string(:normal)
  end

  @doc "Formats a date as `24 Jun 2026` (the year is included so far-future events read correctly)."
  def short_date(nil), do: "Date to be announced"
  def short_date(%Date{} = date), do: Calendar.strftime(date, "%-d %b %Y")

  @doc "Formats a date as `Wednesday, 24 June 2026`."
  def long_date(nil), do: "Date to be announced"
  def long_date(%Date{} = date), do: Calendar.strftime(date, "%A, %-d %B %Y")

  @doc "Day of the month for a date block, e.g. `24`."
  def day_of_month(nil), do: "--"
  def day_of_month(%Date{} = date), do: Calendar.strftime(date, "%-d")

  @doc "Upper-case month abbreviation for a date block, e.g. `JUN`."
  def month_abbr(nil), do: "---"
  def month_abbr(%Date{} = date), do: date |> Calendar.strftime("%b") |> String.upcase()

  defp to_decimal(%Decimal{} = decimal), do: decimal
  defp to_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp to_decimal(value) when is_float(value), do: Decimal.from_float(value) |> Decimal.round(2)
  defp to_decimal(value) when is_binary(value), do: value |> Decimal.parse() |> parse_result()

  defp parse_result({decimal, ""}), do: decimal
  defp parse_result(_other), do: Decimal.new(0)

  defp group_digits(integer) when integer < 0, do: "-" <> group_digits(-integer)

  defp group_digits(integer) do
    integer
    |> Integer.to_string()
    |> do_group_digits()
  end

  defp do_group_digits(digits) when byte_size(digits) <= 3, do: digits

  defp do_group_digits(digits) do
    size = byte_size(digits)
    prefix = binary_part(digits, 0, size - 3)
    last = binary_part(digits, size - 3, 3)
    do_group_digits(prefix) <> "," <> last
  end
end
