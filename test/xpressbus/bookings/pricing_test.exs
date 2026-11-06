defmodule Xpressbus.Bookings.PricingTest do
  use ExUnit.Case, async: true

  alias Xpressbus.Bookings.Pricing

  test "adds the flat convenience fee once per booking" do
    assert %{base_fare: 2000, discount: 0, convenience_fee: 50, final_price: 2050} =
             Pricing.calculate(2000)
  end

  test "applies the fee after the discount" do
    assert %{base_fare: 2000, discount: 500, convenience_fee: 50, final_price: 1550} =
             Pricing.calculate(2000, 500)
  end

  test "does not charge a fee when no booking is active" do
    assert %{base_fare: 0, convenience_fee: 0, final_price: 0} =
             Pricing.calculate(0, 0, booking?: false)
  end

  test "never lets the discount push the total below the convenience fee" do
    assert %{discount: 2000, final_price: 50} = Pricing.calculate(2000, 5000)
  end

  test "falls back to the normal fare when a class price is missing" do
    bus = %{price: "KES 2000", vip_price: nil, business_price: "", first_class_price: nil}

    assert Pricing.price_for_type(bus, :normal) == 2000
    assert Pricing.price_for_type(bus, :vip) == 2000
    assert Pricing.price_for_type(bus, :business) == 2000
    assert Pricing.price_for_type(bus, :first_class) == 2000
  end

  test "seat classes follow the operator's real seat types" do
    normal_only = %{seat_types: ["Normal"]}
    mixed = %{seat_types: ["Normal", "VIP", "Business"]}

    refute Pricing.seat_type_available?(normal_only, ["vip"])
    assert Pricing.seat_type_available?(mixed, ["vip"])
    assert Pricing.seat_type_available?(mixed, ["business"])
    refute Pricing.seat_type_available?(mixed, ["first", "first class", "first_class"])
  end
end
