defmodule Xpressbus.Coupons do
  @moduledoc """
  The Coupons context.
  """

  import Ecto.Query, warn: false
  alias Xpressbus.Repo

  alias Xpressbus.Coupons.Coupon

  @doc """
  Returns the list of coupons.

  ## Examples

      iex> list_coupons()
      [%Coupon{}, ...]

  """
  def list_coupons do
    Repo.all(from(c in Coupon, order_by: [desc: c.inserted_at]))
  end

  @doc """
  Counts total coupons.
  """
  def count_coupons do
    Repo.aggregate(Coupon, :count, :id)
  end

  @doc """
  Gets a coupon by its code.

  Codes are compared case-insensitively so a coupon saved as `save100` can be
  redeemed by typing `SAVE100` (and vice versa).
  """
  def get_coupon_by_code(code) when is_binary(code) do
    code = code |> String.trim()

    from(c in Coupon,
      where: fragment("UPPER(?) = UPPER(?)", c.code, ^code),
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
  Calculates the discount (in KES) for `coupon` on a booking total.

  Handles percentage coupons with an optional cap (including `nil` caps) and
  fixed discounts without raising on missing/legacy decimal values.
  """
  def calculate_discount(%Coupon{type: "fixed"} = coupon, _total) do
    coupon.value |> to_number() |> round_money()
  end

  def calculate_discount(%Coupon{type: "percentage"} = coupon, total) do
    percent = to_number(coupon.value)
    raw = total * percent / 100.0
    cap = to_number(coupon.max_discount)

    discount = if cap > 0 and raw > cap, do: cap, else: raw
    round_money(discount)
  end

  def calculate_discount(_coupon, _total), do: 0

  @doc """
  Validates a coupon code against a booking total.

  Returns `{:ok, coupon, discount_in_kes}` or `{:error, reason}` where reason is
  `:not_found`, `:inactive`, `:expired`, `:usage_limit`, `:no_discount` or
  `{:min_amount, minimum}`.
  """
  def apply_coupon(code, total) when is_integer(total) do
    case get_coupon_by_code(code) do
      nil ->
        {:error, :not_found}

      %Coupon{} = coupon ->
        minimum = to_number(coupon.min_amount)

        cond do
          not coupon.active ->
            {:error, :inactive}

          coupon.expiry_date && Date.compare(coupon.expiry_date, Date.utc_today()) == :lt ->
            {:error, :expired}

          coupon.usage_limit && (coupon.usage_count || 0) >= coupon.usage_limit ->
            {:error, :usage_limit}

          total < minimum ->
            {:error, {:min_amount, round_money(minimum)}}

          true ->
            case calculate_discount(coupon, total) do
              discount when discount > 0 -> {:ok, coupon, discount}
              _ -> {:error, :no_discount}
            end
        end
    end
  end

  defp to_number(nil), do: 0.0
  defp to_number(%Decimal{} = decimal), do: Decimal.to_float(decimal)
  defp to_number(number) when is_integer(number), do: number * 1.0
  defp to_number(number) when is_float(number), do: number

  defp to_number(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _rest} -> number
      :error -> 0.0
    end
  end

  defp round_money(value), do: round(value)

  @doc """
  Gets a single coupon.

  Raises `Ecto.NoResultsError` if the Coupon does not exist.

  ## Examples

      iex> get_coupon!(123)
      %Coupon{}

      iex> get_coupon!(456)
      ** (Ecto.NoResultsError)

  """
  def get_coupon!(id), do: Repo.get!(Coupon, id)

  @doc """
  Creates a coupon.

  ## Examples

      iex> create_coupon(%{field: value})
      {:ok, %Coupon{}}

      iex> create_coupon(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_coupon(attrs) do
    %Coupon{}
    |> Coupon.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a coupon.

  ## Examples

      iex> update_coupon(coupon, %{field: new_value})
      {:ok, %Coupon{}}

      iex> update_coupon(coupon, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_coupon(%Coupon{} = coupon, attrs) do
    coupon
    |> Coupon.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a coupon.

  ## Examples

      iex> delete_coupon(coupon)
      {:ok, %Coupon{}}

      iex> delete_coupon(coupon)
      {:error, %Ecto.Changeset{}}

  """
  def delete_coupon(%Coupon{} = coupon) do
    Repo.delete(coupon)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking coupon changes.

  ## Examples

      iex> change_coupon(coupon)
      %Ecto.Changeset{data: %Coupon{}}

  """
  def change_coupon(%Coupon{} = coupon, attrs \\ %{}) do
    Coupon.changeset(coupon, attrs)
  end
end
