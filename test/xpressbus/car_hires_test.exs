defmodule Xpressbus.CarHiresTest do
  use XpressbusWeb.ConnCase

  alias Xpressbus.CarHires
  alias Xpressbus.Bookings.CarHire
  alias Xpressbus.Repo

  defp attrs(overrides \\ %{}) do
    Map.merge(
      %{
        "car_name" => "Toyota Prado",
        "type" => "Premium SUV",
        "price_per_day" => "12000",
        "location" => "Nairobi",
        "active" => true
      },
      overrides
    )
  end

  test "creates, searches, updates, toggles and deletes car hire rows" do
    assert {:ok, car} = CarHires.create_car_hire(attrs())
    assert car.car_name == "Toyota Prado"

    {cars, total} = CarHires.paginate_car_hires(1, 10, "prado")
    assert total == 1
    assert Enum.any?(cars, &(&1.id == car.id))

    assert {:ok, updated} = CarHires.update_car_hire(car, %{"price_per_day" => "13500"})
    assert Decimal.equal?(updated.price_per_day, Decimal.new("13500.00"))

    assert {:ok, inactive} = CarHires.toggle_active(updated)
    refute inactive.active
    assert CarHires.count_car_hires() == 1

    assert {:ok, _} = CarHires.delete_car_hire(inactive)
    assert is_nil(Repo.get(CarHire, car.id))
  end

  test "rejects a duplicate vehicle at the same location" do
    assert {:ok, _} = CarHires.create_car_hire(attrs())
    assert {:error, changeset} = CarHires.create_car_hire(attrs())
    assert changeset.errors[:car_name]
  end
end
