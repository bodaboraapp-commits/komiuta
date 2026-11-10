defmodule Xpressbus.TravelAssistant do
  @moduledoc """
  Public API for the Chyllz AI travel assistant.

  The assistant has two engines and always returns an answer:

    1. **AI mode** — when `Xpressbus.AI` is configured with an API key, the
       Chat and Food tabs use an OpenAI-compatible model with a prompt grounded
       in the live Chyllz catalogue. Lens and Receipt use the vision model.
    2. **Local mode** — with no key (or if the provider errors/times out), the
       catalogue-grounded guide in `Xpressbus.TravelAssistant.Local` answers
       instead. Receipts are parsed deterministically, so the feature keeps
       working without sending any photo off the device.

  The module also exposes the small catalogue snapshot (`context/0`) and the
  copy used by the panel (greetings, quick prompts, tab guidance).
  """

  alias Xpressbus.Chyllz
  alias Xpressbus.AI
  alias Xpressbus.TravelAssistant.{Local, Money, Prompt, Receipt}

  @max_message_length 1_000

  @doc """
  Returns a bounded snapshot of the active Chyllz catalogue for grounding.

  The assistant never reaches outside these rows for recommendations, which is
  what keeps local and AI answers honest about prices and availability.
  """
  def context do
    %{
      hotels: Chyllz.hotels(limit: 16),
      hidden_gems: Chyllz.hidden_gems(limit: 16),
      car_hires: Chyllz.car_hires(limit: 16),
      events: Chyllz.upcoming_events(limit: 12),
      counts: Chyllz.counts(),
      generated_at: DateTime.utc_now()
    }
  end

  @doc "True when an external AI provider is configured."
  def provider_configured?, do: AI.configured?()

  @doc "Welcome message for a tab."
  def greeting(tab), do: Local.greeting(tab)

  @doc "Quick prompts for a tab's empty state."
  def suggestions(tab), do: Local.suggestions(tab)

  @doc """
  Answers a typed message.

  `tab` is one of `"chat"`, `"lens"`, `"receipt"` or `"food"`. `history` is the
  current thread (newest last). Options:

    * `:use_ai` — force local mode (tests / offline) when `false`
    * `:page` — human-readable page name for the prompt

  Returns a map with `:text`, `:cards`, `:action` and `:source`.
  """
  def respond(tab, prompt, history \\ [], context \\ nil, opts \\ []) do
    prompt = sanitize(prompt)
    context = context || context()
    history = List.wrap(history)
    local = Local.answer(tab, prompt, context, history)

    cond do
      prompt == "" ->
        local_reply(local)

      Keyword.get(opts, :use_ai, true) and tab in ["chat", "food"] and provider_configured?() ->
        case ai_chat(tab, prompt, history, context, opts) do
          {:ok, text} ->
            %{text: text, cards: [], action: nil, source: :ai}

          {:error, _reason} ->
            local_reply(local, degraded: true)
        end

      true ->
        local_reply(local)
    end
  end

  @doc """
  Handles a photo for the Lens or Receipt tab.

  `data_url` is a `data:` URL (base64) produced from the uploaded file. When
  vision is not configured, Lens falls back to caption matching and Receipt
  asks for pasted lines; nothing leaves the server.
  """
  def photo_reply(tab, data_url, caption, context \\ nil, opts \\ []) do
    context = context || context()
    caption = sanitize(caption)

    case tab do
      "lens" ->
        lens_photo(data_url, caption, context, opts)

      "receipt" ->
        receipt_photo(data_url, caption, context, opts)

      _other ->
        %{
          text: "Open the Lens or Receipt tab to use a photo.",
          cards: [],
          action: nil,
          source: :local
        }
    end
  end

  @doc """
  Parses pasted receipt text into a summary plus an assistant reply.

  Returns `%{ok: boolean, text: String.t(), receipt: summary | nil}`.
  """
  def parse_receipt_text(text) do
    case Receipt.parse(text) do
      {:ok, summary} ->
        %{ok: true, text: Receipt.summary_text(summary), receipt: summary}

      {:error, _reason} ->
        %{
          ok: false,
          text: """
          I couldn't find any amounts in that text yet. Paste the receipt lines with the price at the end, for example:

          Chapati 120
          Tilapia 850
          Total 970
          """,
          receipt: nil
        }
    end
  end

  @doc "Converts a parsed receipt into a running-log entry for the panel."
  def expense_entry(%{} = summary) do
    %{
      merchant: summary.merchant,
      date: summary.date,
      currency: summary.currency,
      total: summary.total,
      categories: summary.categories,
      items: summary.items
    }
  end

  @doc "Total of a running expense log as a Decimal."
  def expenses_total(expenses) do
    expenses
    |> List.wrap()
    |> Enum.reduce(Decimal.new(0), fn expense, total ->
      Decimal.add(total, Money.to_decimal(expense.total))
    end)
  end

  @doc "Formatted total for the receipt panel, or nil when nothing is logged."
  def expense_total_label([]), do: nil
  def expense_total_label(expenses), do: Money.format_with_code(expenses_total(expenses), "KES")

  @doc "Human-readable label for the local fallback, used by the UI footer."
  def engine_label, do: if(provider_configured?(), do: "Chyllz AI", else: "Chyllz Guide")

  # --- engines ---------------------------------------------------------------

  defp lens_photo(data_url, caption, context, opts) do
    cond do
      valid_data_url?(data_url) and provider_configured?() ->
        messages = [
          %{"role" => "system", "content" => Prompt.lens_system_prompt(context)},
          Prompt.lens_message(caption, data_url, context)
        ]

        case ai_vision(messages, opts) do
          {:ok, text} -> %{text: text, cards: [], action: nil, source: :ai}
          {:error, _reason} -> local_photo_reply(caption, context)
        end

      true ->
        local_photo_reply(caption, context)
    end
  end

  defp local_photo_reply(caption, context) do
    reply = Local.photo_reply(caption, context)
    local_reply(reply)
  end

  defp receipt_photo(data_url, caption, _context, opts) do
    cond do
      valid_data_url?(data_url) and provider_configured?() ->
        messages = [
          %{"role" => "system", "content" => Prompt.receipt_system_prompt()},
          Prompt.receipt_message(data_url)
        ]

        case ai_vision(messages, opts) do
          {:ok, text} ->
            case parse_receipt_json(text) do
              {:ok, summary} ->
                %{
                  text: Receipt.summary_text(summary),
                  cards: [],
                  action: nil,
                  source: :ai,
                  receipt: summary
                }

              {:error, reason} ->
                receipt_fallback(reason, caption)
            end

          {:error, _reason} ->
            receipt_fallback(:provider_error, caption)
        end

      true ->
        receipt_fallback(:no_vision, caption)
    end
  end

  defp receipt_fallback(_reason, caption) do
    case Receipt.parse(caption) do
      {:ok, summary} ->
        %{
          text: Receipt.summary_text(summary),
          cards: [],
          action: nil,
          source: :local,
          receipt: summary
        }

      {:error, _reason} ->
        %{
          text: """
          I can't read the photo directly in this setup — but I can still total your receipt if you paste the lines below, one item per line, with the price at the end.

          Chapati 120
          Tilapia 850
          Total 970
          """,
          cards: [],
          action: nil,
          source: :local
        }
    end
  end

  defp ai_chat(tab, prompt, history, context, opts) do
    page = Keyword.get(opts, :page, "Chyllz")
    messages = Prompt.chat_messages(history, prompt, context, page: page, tab: tab)
    AI.chat(messages, max_tokens: 700)
  end

  defp ai_vision(messages, opts) do
    config = AI.config()

    AI.chat(messages,
      model: config.vision_model || config.model,
      max_tokens: Keyword.get(opts, :max_tokens, 700)
    )
  end

  defp parse_receipt_json(text) when is_binary(text) do
    text
    |> strip_code_fence()
    |> extract_json_object()
    |> case do
      nil ->
        {:error, :invalid_json}

      json ->
        case Jason.decode(json) do
          {:ok, %{"error" => _message}} ->
            {:error, :not_a_receipt}

          {:ok, %{"total" => total} = data}
          when is_number(total) or is_binary(total) ->
            summary =
              Receipt.from_extracted(
                data["merchant"],
                data["date"],
                data["currency"],
                total,
                data["items"] || []
              )

            if Decimal.compare(summary.total, 0) == :gt do
              {:ok, summary}
            else
              {:error, :no_total}
            end

          {:ok, _data} ->
            {:error, :bad_shape}

          {:error, _decode_error} ->
            {:error, :invalid_json}
        end
    end
  end

  defp parse_receipt_json(_text), do: {:error, :invalid_json}

  defp strip_code_fence(text) do
    text
    |> String.replace(~r/^```[a-zA-Z]*\s*/m, "")
    |> String.replace(~r/```$/m, "")
    |> String.trim()
  end

  defp extract_json_object(text) do
    with {start, _length} <- :binary.match(text, "{"),
         {last, _length} <- text |> :binary.matches("}") |> List.last() do
      binary_part(text, start, last - start + 1)
    else
      _other -> nil
    end
  end

  defp local_reply(reply, opts \\ []) do
    %{
      text: reply.text,
      cards: reply.cards || [],
      action: reply.action,
      source: :local,
      degraded: Keyword.get(opts, :degraded, false)
    }
  end

  defp valid_data_url?(data_url) do
    is_binary(data_url) and String.starts_with?(data_url, "data:image/") and
      byte_size(data_url) > 50
  end

  defp sanitize(text) when is_binary(text) do
    text
    |> String.replace(~r/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "")
    |> String.replace(~r/[^\S\n]+/, " ")
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
    |> String.slice(0, @max_message_length)
  end

  defp sanitize(_text), do: ""
end
