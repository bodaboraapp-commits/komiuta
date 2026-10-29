defmodule Xpressbus.QRTest do
  use ExUnit.Case, async: true

  alias Xpressbus.QR

  # Independent reference matrix, captured from a well-known third-party QR
  # implementation (qrcode.show) for the byte-mode payload "helloqr",
  # error-correction level M and mask 0. The encoder must reproduce it exactly.
  @reference_matrix ~w(
    111111100100001111111
    100000101100101000001
    101110100010101011101
    101110100010101011101
    101110101110101011101
    100000100000101000001
    111111101010101111111
    000000000111100000000
    101010100011000010010
    001001010000001100011
    110111111110100011111
    111101001000001110010
    010111110010101010000
    000000001011010010111
    111111100101011110111
    100000100011110000001
    101110101111011010011
    101110100000001010110
    101110101000100110101
    100000100000001010010
    111111101110101100011
  )

  defp matrix_strings(%{modules: modules}) do
    Enum.map(modules, fn row ->
      Enum.map_join(row, fn dark? -> if dark?, do: "1", else: "0" end)
    end)
  end

  test "matches an independent reference implementation exactly" do
    assert {:ok, qr} = QR.encode("helloqr", mask: 0)
    assert qr.version == 1
    assert qr.size == 21
    assert matrix_strings(qr) == @reference_matrix
  end

  test "selects the correct version for payload sizes" do
    assert {:ok, %{version: 1}} = QR.encode(String.duplicate("a", 10))
    assert {:ok, %{version: 2}} = QR.encode(String.duplicate("a", 20))
    assert {:ok, %{version: 3}} = QR.encode(String.duplicate("a", 30))
    assert {:ok, %{version: 4}} = QR.encode(String.duplicate("a", 60))
    assert {:ok, %{version: 6}} = QR.encode(String.duplicate("a", 100))
    assert {:ok, %{version: 8}} = QR.encode(String.duplicate("a", 140))
    assert {:ok, %{version: 10}} = QR.encode(String.duplicate("a", 213))
  end

  test "returns an error when the payload does not fit version 10" do
    assert {:error, :too_long} = QR.encode(String.duplicate("a", 214))
  end

  test "draws finder patterns, timing patterns and the dark module" do
    assert {:ok, qr} = QR.encode("http://localhost/tickets?ticket_id=TKT-RJPTCA")
    modules = qr.modules
    size = qr.size

    dark = fn row, column -> Enum.at(Enum.at(modules, row), column) end

    # Finder patterns: 7x7 with a dark border and a dark 3x3 centre.
    for {row, column} <- [{0, 0}, {0, size - 7}, {size - 7, 0}] do
      assert dark.(row, column)
      assert dark.(row + 1, column + 0)
      assert dark.(row + 2, column + 2)
      assert dark.(row + 6, column + 6)
      assert not dark.(row + 1, column + 1)
    end

    # Timing pattern alternates dark/light starting dark at even coordinates.
    for index <- 8..(size - 9) do
      assert dark.(6, index) == (rem(index, 2) == 0)
      assert dark.(index, 6) == (rem(index, 2) == 0)
    end

    # Fixed dark module at (row size-8, column 8).
    assert dark.(size - 8, 8)
  end

  test "renders a self-contained SVG with no third-party references" do
    assert {:ok, svg} =
             QR.svg("http://localhost/tickets?ticket_id=TKT-RJPTCA",
               aria_label: "Boarding QR code"
             )

    assert svg =~ "<svg"
    assert svg =~ "viewBox="
    assert svg =~ "aria-label=\"Boarding QR code\""
    refute svg =~ "qrserver"
    refute svg =~ "https://api."
  end

  test "automatic mask selection returns a valid mask" do
    assert {:ok, qr} = QR.encode("helloqr")
    assert qr.mask in 0..7
  end

  test "QRCode helper returns safe inline SVG for direct rendering" do
    assert {:safe, svg} =
             XpressbusWeb.QRCode.svg("https://komiuta.example/?source=qr_app_section")

    html = IO.iodata_to_binary(svg)

    assert html =~ "<svg"
    assert html =~ "viewBox="
    refute html =~ "qrserver"
  end
end
