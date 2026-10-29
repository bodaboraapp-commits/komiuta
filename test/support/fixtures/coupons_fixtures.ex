defmodule Xpressbus.CouponsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Xpressbus.Coupons` context.
  """

  @doc """
  Generate a unique coupon code.
  """
  def unique_coupon_code, do: "some code#{System.unique_integer([:positive])}"

  @doc """
  Generate a coupon.
  """
  def coupon_fixture(attrs \\ %{}) do
    {:ok, coupon} =
      attrs
      |> Enum.into(%{
        active: true,
        code: unique_coupon_code(),
        expiry_date: ~D[2026-09-05],
        max_discount: "120.5",
        min_amount: "120.5",
        type: "some type",
        usage_count: 42,
        usage_limit: 42,
        value: "120.5"
      })
      |> Xpressbus.Coupons.create_coupon()

    coupon
  end
end
