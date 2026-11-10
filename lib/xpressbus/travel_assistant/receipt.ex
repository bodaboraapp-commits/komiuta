defmodule Xpressbus.TravelAssistant.Receipt do
  @moduledoc """
  Deterministic receipt parser for the assistant's Receipt tab.

  AI vision is optional: when no provider is configured (or a photo cannot be
  read), travellers can paste the receipt text and still get a reliable total,
  category breakdown and running trip-spend log. The parser intentionally errs
  on the side of ignoring ambiguous lines rather than inventing amounts.
  """

  alias Xpressbus.TravelAssistant.Money

  @amount_regex ~r/^(?<label>.+?)\s*[:=]?\s*(?:(?:ksh|kes|kshs)\s*)?(?<amount>\d[\d,]*(?:\.\d{1,2})?)\s*(?:\/-)?$/i

  @date_line_regex ~r/^\s*(?:\d{4}-\d{1,2}-\d{1,2}|\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}|\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4})\s*$/

  @total_keywords ~r/\b(grand\s+total|total\s+due|total\s+paid|amount\s+due|total)\b/i
  @grand_total_keywords ~r/\bgrand\s+total\b/i
  @tax_keywords ~r/\b(vat|tax|service\s+(?:charge|fee)|levy|gst)\b/i
  @payment_keywords ~r/\b(cash|change|tendered|mpesa|m-pesa|card|balance|paid|payment|deposit|reference|ref\s*#?)\b/i

  @category_keywords [
    {"Transport",
     ~w(bus matatu taxi uber bolt fuel petrol diesel parking shuttle fare ride transport transfer)},
    {"Food",
     ~w(breakfast lunch dinner meal food restaurant cafe coffee tea water soda juice beer wine snack chapati
        ugali nyama rice pilau biryani samosa mahamri mandazi bhajia sukuma fish tilapia snapper prawns
        octopus seafood chicken mbaazi)},
    {"Stay", ~w(room hotel lodge night accommodation bed stay resort apartment)},
    {"Activities", ~w(park museum tour safari ticket entry event concert activity hiking boat)},
    {"Shopping", ~w(souvenir shop gift market mall store boutique)}
  ]

  @type summary :: %{
          merchant: String.t() | nil,
          date: String.t() | nil,
          currency: String.t(),
          total: Decimal.t(),
          items: [%{label: String.t(), amount: Decimal.t(), category: String.t()}],
          categories: %{String.t() => Decimal.t()},
          advice: String.t()
        }

  @doc """
  Parses a receipt from free text.

  Returns `{:ok, summary}` when at least one amount is found, otherwise
  `{:error, :empty}` or `{:error, :no_amounts}`.
  """
  def parse(text) when is_binary(text) do
    text = normalize(text)

    if String.length(text) < 3 do
      {:error, :empty}
    else
      lines = text |> String.split("\n", trim: true) |> Enum.map(&String.trim/1)

      classified = Enum.map(lines, &classify_line/1)
      items = for {:item, item} <- classified, do: item
      taxes = for {:tax, amount} <- classified, do: amount
      total = choose_total(classified, items, taxes)

      if total == nil or (items == [] and Decimal.equal?(total, 0)) do
        {:error, :no_amounts}
      else
        categories = category_totals(items)
        merchant = merchant(lines)
        date = receipt_date(text)

        {:ok,
         %{
           merchant: merchant,
           date: date,
           currency: detect_currency(text),
           total: total,
           items: items,
           categories: categories,
           advice: advice(total, categories, items)
         }}
      end
    end
  end

  def parse(_text), do: {:error, :empty}

  @doc """
  Builds a summary from AI-extracted parts (used for receipt-vision responses).

  Categories are normalised against the parser's known categories, amounts are
  coerced to `Decimal`, and the total falls back to the sum of the items.
  """
  def from_extracted(merchant, date, currency, total, raw_items) do
    items =
      raw_items
      |> List.wrap()
      |> Enum.map(fn item ->
        label = clean_label(to_string(item["label"] || item["name"] || "Item"))
        amount = Money.to_decimal(item["amount"] || item["price"])

        %{
          label: label,
          amount: amount,
          category: normalize_category(item["category"], label)
        }
      end)
      |> Enum.reject(fn item -> item.label == "" or Decimal.equal?(item.amount, 0) end)

    categories = category_totals(items)

    extracted_total = Money.to_decimal(total)

    total =
      if Decimal.equal?(extracted_total, 0) do
        Enum.reduce(items, Decimal.new(0), &Decimal.add(&2, &1.amount))
      else
        extracted_total
      end

    %{
      merchant: blank_to_nil(merchant),
      date: blank_to_nil(date),
      currency: normalize_currency(currency),
      total: total,
      items: items,
      categories: categories,
      advice: advice(total, categories, items)
    }
  end

  @doc "Renders a parsed receipt as a concise, plain-text assistant reply."
  def summary_text(%{} = summary) do
    currency = summary.currency
    total = Money.format_with_code(summary.total, currency)

    heading =
      [summary.merchant, summary.date]
      |> Enum.reject(&is_nil/1)
      |> case do
        [] -> "Receipt captured."
        parts -> "Receipt captured — " <> Enum.join(parts, " · ")
      end

    breakdown =
      summary.categories
      |> Enum.sort_by(fn {_category, amount} -> amount end, :desc)
      |> Enum.map(fn {category, amount} ->
        share = Money.percent(amount, summary.total)
        "• #{category}: #{Money.format_with_code(amount, currency)} (#{share}%)"
      end)

    top_items =
      summary.items
      |> Enum.sort_by(& &1.amount, :desc)
      |> Enum.take(4)
      |> Enum.map(fn item ->
        "• #{item.label} — #{Money.format_with_code(item.amount, currency)}"
      end)

    [
      heading,
      "",
      "Total: #{total}",
      breakdown == [] && nil,
      breakdown,
      top_items == [] && nil,
      top_items != [] && "",
      top_items == [] && nil,
      top_items != [] && "Largest items:",
      top_items != [] && top_items,
      "",
      summary.advice
    ]
    |> List.flatten()
    |> Enum.reject(&(&1 in [nil, false]))
    |> Enum.join("\n")
    |> String.replace("\n\n\n", "\n\n")
    |> String.trim()
  end

  @doc "Maps a receipt line label to a spend category."
  def category_for(label) do
    label = to_string(label || "")
    apply_category(label)
  end

  defp normalize_category(category, label) do
    known = ~w(Food Transport Stay Activities Shopping Other)

    case Enum.find(known, &(String.downcase(&1) == String.downcase(to_string(category || "")))) do
      nil -> apply_category(label)
      category -> category
    end
  end

  defp normalize_currency(currency) do
    case to_string(currency || "") |> String.upcase() do
      "USD" -> "USD"
      "TZS" -> "TZS"
      "UGX" -> "UGX"
      "KES" -> "KES"
      _other -> "KES"
    end
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value),
    do: if(String.trim(to_string(value)) == "", do: nil, else: String.trim(to_string(value)))

  defp apply_category(label) do
    normalized = label |> to_string() |> String.downcase()

    Enum.find_value(@category_keywords, "Other", fn {category, words} ->
      if Enum.any?(words, &Regex.match?(~r/\b#{Regex.escape(&1)}\b/, normalized)) do
        category
      end
    end)
  end

  defp normalize(text) do
    text
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> String.replace(~r/[^\S\n]+/, " ")
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.slice(0, 20_000)
  end

  defp classify_line(""), do: :skip

  defp classify_line(line) do
    if Regex.match?(@date_line_regex, line) do
      :skip
    else
      case Regex.named_captures(@amount_regex, line) do
        %{"label" => label, "amount" => amount} ->
          label = clean_label(label)
          decimal = Money.to_decimal(amount)

          cond do
            label == "" -> :skip
            not String.match?(label, ~r/[A-Za-z]/) -> :skip
            Regex.match?(@total_keywords, label) -> {:total, label, decimal}
            Regex.match?(@tax_keywords, label) -> {:tax, decimal}
            Regex.match?(@payment_keywords, label) -> :skip
            decimal |> Decimal.equal?(0) -> :skip
            true -> {:item, %{label: label, amount: decimal, category: category_for(label)}}
          end

        nil ->
          :skip
      end
    end
  end

  defp clean_label(label) do
    label
    |> String.replace(~r/^\d+\s*[xX*]\s*/, "")
    |> String.replace(~r/\s+[@=]\s*$/, "")
    |> String.replace(~r/\s{2,}/, " ")
    |> String.trim(" .:-")
    |> String.slice(0, 80)
  end

  defp choose_total(classified, items, taxes) do
    totals = for {:total, label, amount} <- classified, do: {label, amount}

    cond do
      totals == [] ->
        sum = Enum.reduce(items, Decimal.new(0), &Decimal.add(&2, &1.amount))
        sum = Enum.reduce(taxes, sum, &Decimal.add(&2, &1))
        if Decimal.equal?(sum, 0), do: nil, else: sum

      true ->
        grand =
          Enum.find(totals, fn {label, _amount} -> Regex.match?(@grand_total_keywords, label) end)

        {_label, amount} = grand || List.last(totals)
        amount
    end
  end

  defp category_totals(items) do
    items
    |> Enum.group_by(& &1.category, & &1.amount)
    |> Map.new(fn {category, amounts} ->
      {category, Enum.reduce(amounts, Decimal.new(0), &Decimal.add(&2, &1))}
    end)
  end

  defp merchant(lines) do
    lines
    |> Enum.reject(fn line ->
      line == "" or Regex.match?(@amount_regex, line) or
        Regex.match?(
          ~r/^(receipt|invoice|tax invoice|order|table|date|time|cashier|server|tel|phone)\b/i,
          line
        )
    end)
    |> Enum.find(fn line ->
      String.match?(line, ~r/[A-Za-z]{3,}/) and String.length(line) <= 80
    end)
  end

  defp receipt_date(text) do
    patterns = [
      ~r/\b(\d{4})-(\d{2})-(\d{2})\b/,
      ~r/\b(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})\b/,
      ~r/\b(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\s+(\d{4})\b/i
    ]

    Enum.find_value(patterns, fn pattern ->
      case Regex.run(pattern, text, capture: :first) do
        [match] -> match
        _other -> nil
      end
    end)
  end

  defp detect_currency(text) do
    cond do
      Regex.match?(~r/\b(kshs?|kes)\b/i, text) -> "KES"
      String.contains?(text, "$") -> "USD"
      Regex.match?(~r/\b(tzs|tsh)\b/i, text) -> "TZS"
      Regex.match?(~r/\b(ugx|ushs?)\b/i, text) -> "UGX"
      true -> "KES"
    end
  end

  defp advice(total, categories, items) do
    currency = "KES"
    total_text = Money.format_with_code(total, currency)

    top =
      categories
      |> Enum.sort_by(fn {_category, amount} -> amount end, :desc)
      |> List.first()

    cond do
      items == [] ->
        "I found the receipt total (#{total_text}) but no item lines. Paste the itemised lines for a spend breakdown."

      total |> Decimal.gt?(10_000) ->
        "That's a big day of spending (#{total_text}). Keep it in your trip budget and double-check any deposits are refundable." <>
          top_category_note(top, total, currency)

      true ->
        "Logged #{total_text} into this trip." <> top_category_note(top, total, currency)
    end
  end

  defp top_category_note(nil, _total, _currency), do: ""

  defp top_category_note({category, amount}, total, currency) do
    share = Money.percent(amount, total)

    cond do
      share >= 60 ->
        " #{category} is #{share}% of the spend — a good place to trim if you want to stretch the budget."

      true ->
        " The biggest category is #{category} at #{Money.format_with_code(amount, currency)} (#{share}%)."
    end
  end
end
