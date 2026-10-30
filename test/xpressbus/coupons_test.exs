defmodule Xpressbus.CouponsTest do
  use Xpressbus.DataCase

  alias Xpressbus.Coupons
  alias Xpressbus.Coupons.Coupon

  describe "coupons" do
    alias Xpressbus.Coupons.Coupon

    import Xpressbus.CouponsFixtures

    @invalid_attrs %{
      active: nil,
      code: nil,
      type: nil,
      value: nil,
      min_amount: nil,
      max_discount: nil,
      expiry_date: nil,
      usage_limit: nil,
      usage_count: nil
    }

    test "list_coupons/0 returns all coupons" do
      coupon = coupon_fixture()
      assert Coupons.list_coupons() == [coupon]
    end

    test "get_coupon!/1 returns the coupon with given id" do
      coupon = coupon_fixture()
      assert Coupons.get_coupon!(coupon.id) == coupon
    end

    test "create_coupon/1 with valid data creates a coupon" do
      valid_attrs = %{
        active: true,
        code: "some code",
        type: "fixed",
        value: "120.5",
        min_amount: "120.5",
        max_discount: "120.5",
        expiry_date: ~D[2026-09-05],
        usage_limit: 42,
        usage_count: 42
      }

      assert {:ok, %Coupon{} = coupon} = Coupons.create_coupon(valid_attrs)
      assert coupon.active == true
      assert coupon.code == "SOME CODE"
      assert coupon.type == "fixed"
      assert coupon.value == Decimal.new("120.5")
      assert coupon.min_amount == Decimal.new("120.5")
      assert coupon.max_discount == Decimal.new("120.5")
      assert coupon.expiry_date == ~D[2026-09-05]
      assert coupon.usage_limit == 42
      assert coupon.usage_count == 42
    end

    test "create_coupon/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Coupons.create_coupon(@invalid_attrs)
    end

    test "update_coupon/2 with valid data updates the coupon" do
      coupon = coupon_fixture()

      update_attrs = %{
        active: false,
        code: "some updated code",
        type: "percentage",
        value: "15",
        min_amount: "456.7",
        max_discount: "456.7",
        expiry_date: ~D[2026-09-06],
        usage_limit: 43,
        usage_count: 43
      }

      assert {:ok, %Coupon{} = coupon} = Coupons.update_coupon(coupon, update_attrs)
      assert coupon.active == false
      assert coupon.code == "SOME UPDATED CODE"
      assert coupon.type == "percentage"
      assert coupon.value == Decimal.new("15")
      assert coupon.min_amount == Decimal.new("456.7")
      assert coupon.max_discount == Decimal.new("456.7")
      assert coupon.expiry_date == ~D[2026-09-06]
      assert coupon.usage_limit == 43
      assert coupon.usage_count == 43
    end

    test "update_coupon/2 with invalid data returns error changeset" do
      coupon = coupon_fixture()
      assert {:error, %Ecto.Changeset{}} = Coupons.update_coupon(coupon, @invalid_attrs)
      assert coupon == Coupons.get_coupon!(coupon.id)
    end

    test "delete_coupon/1 deletes the coupon" do
      coupon = coupon_fixture()
      assert {:ok, %Coupon{}} = Coupons.delete_coupon(coupon)
      assert_raise Ecto.NoResultsError, fn -> Coupons.get_coupon!(coupon.id) end
    end

    test "change_coupon/1 returns a coupon changeset" do
      coupon = coupon_fixture()
      assert %Ecto.Changeset{} = Coupons.change_coupon(coupon)
    end
  end

  describe "applying coupons at checkout" do
    alias Xpressbus.Repo

    defp checkout_coupon(attrs) do
      attrs =
        Enum.into(attrs, %{
          active: true,
          code: "CHECKOUT#{System.unique_integer([:positive])}",
          type: "percentage",
          value: "10",
          min_amount: "0",
          expiry_date: Date.add(Date.utc_today(), 7)
        })

      {:ok, coupon} = Coupons.create_coupon(attrs)
      coupon
    end

    test "legacy lower-case coupons still redeem (save100 regression)" do
      # Mirrors the production row: percentage 99, max_discount NULL, code lower-case.
      {:ok, _} =
        Repo.insert(%Coupon{
          code: "save100",
          type: "percentage",
          value: Decimal.new("99"),
          min_amount: Decimal.new("0"),
          max_discount: nil,
          expiry_date: Date.add(Date.utc_today(), 7),
          usage_count: 0,
          active: true
        })

      assert {:ok, %Coupon{code: "save100"}, 4950} = Coupons.apply_coupon("SAVE100", 5000)
      assert {:ok, _coupon, 4950} = Coupons.apply_coupon(" save100 ", 5000)
    end

    test "percentage discounts respect an optional cap" do
      coupon = checkout_coupon(%{value: "50", max_discount: "1000"})

      assert {:ok, _coupon, 1000} = Coupons.apply_coupon(coupon.code, 5000)
      assert {:ok, _coupon, 250} = Coupons.apply_coupon(coupon.code, 500)
    end

    test "fixed discounts apply without a cap" do
      coupon = checkout_coupon(%{type: "fixed", value: "300"})

      assert {:ok, _coupon, 300} = Coupons.apply_coupon(coupon.code, 2600)
    end

    test "minimum spend is enforced" do
      coupon = checkout_coupon(%{min_amount: "2000"})

      assert {:error, {:min_amount, 2000}} = Coupons.apply_coupon(coupon.code, 1500)
      assert {:ok, _coupon, discount} = Coupons.apply_coupon(coupon.code, 2000)
      assert discount > 0
    end

    test "inactive, expired and exhausted coupons are rejected" do
      inactive = checkout_coupon(%{active: false})
      assert {:error, :inactive} = Coupons.apply_coupon(inactive.code, 2000)

      expired = checkout_coupon(%{expiry_date: Date.add(Date.utc_today(), -1)})
      assert {:error, :expired} = Coupons.apply_coupon(expired.code, 2000)

      exhausted = checkout_coupon(%{usage_limit: 1, usage_count: 1})
      assert {:error, :usage_limit} = Coupons.apply_coupon(exhausted.code, 2000)
    end

    test "unknown codes and zero discounts are rejected" do
      assert {:error, :not_found} = Coupons.apply_coupon("DOES-NOT-EXIST", 2000)

      tiny = checkout_coupon(%{type: "fixed", value: "0.4"})
      assert {:error, :no_discount} = Coupons.apply_coupon(tiny.code, 2000)
    end
  end
end
