defmodule Xpressbus.TravelAssistant.ReceiptTest do
  use ExUnit.Case, async: true

  alias Xpressbus.TravelAssistant.Receipt

  describe "parse/1" do
    test "reads merchant, date, total and item categories" do
      text = """
      KOMIUTA CAFE
      Nairobi
      12/11/2026
      2 x Chapati 120
      Tilapia 850
      Water 100
      VAT 80
      Total 1,150
      Cash 1,500
      Change 350
      """

      assert {:ok, summary} = Receipt.parse(text)
      assert summary.merchant == "KOMIUTA CAFE"
      assert summary.date == "12/11/2026"
      assert summary.currency == "KES"
      assert Decimal.equal?(summary.total, Decimal.new(1_150))

      labels = Enum.map(summary.items, & &1.label)

      assert "Chapati" in labels
      assert "Tilapia" in labels
      assert "Water" in labels
      refute "Cash" in labels
      refute "Change" in labels
      refute "VAT" in labels
      assert Decimal.equal?(summary.categories["Food"], Decimal.new(1_070))
    end

    test "falls back to summing item lines when there is no total line" do
      assert {:ok, summary} = Receipt.parse("Matatu 100\nLunch 300")
      assert Decimal.equal?(summary.total, Decimal.new(400))
      assert Decimal.equal?(summary.categories["Transport"], Decimal.new(100))
      assert Decimal.equal?(summary.categories["Food"], Decimal.new(300))
    end

    test "adds tax to items only when the receipt has no total line" do
      assert {:ok, summary} = Receipt.parse("Room 5,000\nVAT 800")
      assert Decimal.equal?(summary.total, Decimal.new(5_800))
    end

    test "detects other currencies" do
      assert {:ok, summary} = Receipt.parse("Lunch $12.50\nTotal $12.50")
      assert summary.currency == "USD"
      assert Decimal.equal?(summary.total, Decimal.new("12.50"))
    end

    test "ignores dates that look like line items" do
      assert {:ok, summary} = Receipt.parse("KOMIUTA\n2026-11-12\nBoda 250\nTotal 250")
      refute Enum.any?(summary.items, &(&1.label =~ "2026"))
    end

    test "returns an error when there are no amounts" do
      assert {:error, :no_amounts} = Receipt.parse("Thank you for visiting\nNo prices here")
      assert {:error, :empty} = Receipt.parse("   ")
    end

    test "summary_text renders the total and category breakdown" do
      {:ok, summary} = Receipt.parse("Chapati 120\nTilapia 850\nTotal 970")
      text = Receipt.summary_text(summary)

      assert text =~ "Total: KES 970"
      assert text =~ "Food"
      assert text =~ "Largest items"
    end
  end

  describe "from_extracted/5" do
    test "normalises AI-extracted parts and recomputes category totals" do
      summary =
        Receipt.from_extracted("Beach Cafe", "14 Nov 2026", "kes", nil, [
          %{"label" => "Grilled fish", "amount" => "850", "category" => "food"},
          %{"label" => "Taxi", "amount" => "300", "category" => "Transport"}
        ])

      assert summary.merchant == "Beach Cafe"
      assert summary.currency == "KES"
      assert Decimal.equal?(summary.total, Decimal.new(1_150))
      assert Decimal.equal?(summary.categories["Food"], Decimal.new(850))
      assert Decimal.equal?(summary.categories["Transport"], Decimal.new(300))
    end

    test "maps unknown categories from the item label" do
      summary =
        Receipt.from_extracted(nil, nil, nil, 0, [
          %{"label" => "Matatu fare", "amount" => 120, "category" => "Weird"}
        ])

      assert Decimal.equal?(summary.total, Decimal.new(120))
      assert summary.categories["Transport"]
    end
  end
end
