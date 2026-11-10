defmodule Xpressbus.LegacyPriceNormalizerTest do
  use ExUnit.Case, async: true

  alias Xpressbus.LegacyPriceNormalizer

  test "normalises KSH and Ksh price labels to KES" do
    assert LegacyPriceNormalizer.normalise("KSH 2,300") == "KES 2,300"
    assert LegacyPriceNormalizer.normalise("Ksh 1,800") == "KES 1,800"
    assert LegacyPriceNormalizer.normalise("kshs 500") == "KES 500"
    assert LegacyPriceNormalizer.normalise("KSH2,000") == "KES2,000"
    assert LegacyPriceNormalizer.normalise("KES 2,000") == "KES 2,000"
    assert LegacyPriceNormalizer.normalise(nil) == nil
    assert LegacyPriceNormalizer.normalise(2_000) == 2_000
  end

  test "normalises nested JSON values used by bus seat types" do
    value = %{
      "vip" => %{"label" => "VIP", "price" => "KSH 2,300"},
      "classes" => [%{"price" => "Ksh 1,800"}],
      "currency" => "KES"
    }

    assert LegacyPriceNormalizer.deep_normalise(value) == %{
             "vip" => %{"label" => "VIP", "price" => "KES 2,300"},
             "classes" => [%{"price" => "KES 1,800"}],
             "currency" => "KES"
           }
  end
end
