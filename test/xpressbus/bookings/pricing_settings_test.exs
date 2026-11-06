defmodule Xpressbus.Bookings.PricingSettingsTest do
  use Xpressbus.DataCase, async: false

  alias Xpressbus.Bookings.PricingSettings

  test "returns safe defaults when nothing is configured" do
    assert PricingSettings.get() == %{convenience_fee: 50, tax_rate: 0.0}
  end

  test "persists convenience fee and tax rate for checkout" do
    assert {:ok, settings} =
             PricingSettings.update(%{"convenience_fee" => "75", "tax_rate" => "16"})

    assert settings.convenience_fee == 75
    assert settings.tax_rate == 16.0
    assert PricingSettings.get() == %{convenience_fee: 75, tax_rate: 16.0}
  end

  test "rejects invalid fee or tax values" do
    assert {:error, changeset} =
             PricingSettings.update(%{"convenience_fee" => "-1", "tax_rate" => "16"})

    assert errors_on(changeset)[:convenience_fee]

    assert {:error, changeset} =
             PricingSettings.update(%{"convenience_fee" => "50", "tax_rate" => "101"})

    assert errors_on(changeset)[:tax_rate]
  end
end
