defmodule Xpressbus.CouponsTest do
  use Xpressbus.DataCase

  alias Xpressbus.Coupons

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
        type: "some type",
        value: "120.5",
        min_amount: "120.5",
        max_discount: "120.5",
        expiry_date: ~D[2026-09-05],
        usage_limit: 42,
        usage_count: 42
      }

      assert {:ok, %Coupon{} = coupon} = Coupons.create_coupon(valid_attrs)
      assert coupon.active == true
      assert coupon.code == "some code"
      assert coupon.type == "some type"
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
        type: "some updated type",
        value: "456.7",
        min_amount: "456.7",
        max_discount: "456.7",
        expiry_date: ~D[2026-09-06],
        usage_limit: 43,
        usage_count: 43
      }

      assert {:ok, %Coupon{} = coupon} = Coupons.update_coupon(coupon, update_attrs)
      assert coupon.active == false
      assert coupon.code == "some updated code"
      assert coupon.type == "some updated type"
      assert coupon.value == Decimal.new("456.7")
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
end
