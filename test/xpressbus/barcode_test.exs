defmodule Xpressbus.BarcodeTest do
  use ExUnit.Case, async: true

  alias Xpressbus.Barcode

  # ISO/IEC 15417 reference patterns used in the assertions below.
  @start_b "11010010000"
  @stop "1100011101011"
  @pattern_a "10100011000"
  @pattern_checksum_34 "10001011000"

  test "encodes Code 128B with start, checksum and stop symbols" do
    # 'A' = value 33; checksum = (104 + 33 * 1) mod 103 = 34.
    assert {:ok, bits} = Barcode.encode("A")

    assert bits == @start_b <> @pattern_a <> @pattern_checksum_34 <> @stop
    assert String.starts_with?(bits, @start_b)
    assert String.ends_with?(bits, @stop)
  end

  test "uses the weighted mod-103 checksum" do
    # PJJ123C in code set B: start 104, values 48,42,42,17,18,19,35.
    # checksum = 104 + 48*1 + 42*2 + 42*3 + 17*4 + 18*5 + 19*6 + 35*7 = 879
    # 879 mod 103 = 55, whose symbol is "11101000110" (V).
    assert {:ok, bits} = Barcode.encode("PJJ123C")
    assert String.ends_with?(bits, "11101000110" <> @stop)
  end

  test "supports ticket IDs with mixed case and hyphens" do
    assert {:ok, bits} = Barcode.encode("TKT-tEhzHQ")
    assert String.ends_with?(bits, @stop)
    assert byte_size(bits) == 11 * (1 + 10 + 1) + 13
  end

  test "rejects empty and non-ASCII payloads" do
    assert {:error, :empty} = Barcode.encode("")
    assert {:error, :unsupported_character} = Barcode.encode("café")
  end

  test "renders a quiet-zoned SVG with human-readable aria label" do
    assert {:ok, svg} = Barcode.svg("TKT-tEhzHQ", module_width: 2, height: 64)

    assert svg =~ ~s(aria-label="Barcode")
    assert svg =~ ~s(shape-rendering="crispEdges")
    assert svg =~ ~s(fill="#ffffff")

    # 10 characters + start + checksum = 12 symbols of 11 modules, plus stop (13).
    modules = 11 * (1 + 10 + 1) + 13
    total_modules = modules + 20
    assert svg =~ ~s(width="#{total_modules * 2}")
    assert svg =~ ~s(viewBox="0 0 #{total_modules * 2} 64")

    # Bars start after the 10-module quiet zone.
    assert svg =~ ~s(x="20" y="0")
  end
end
