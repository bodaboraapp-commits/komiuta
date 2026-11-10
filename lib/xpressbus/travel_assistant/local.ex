defmodule Xpressbus.TravelAssistant.Local do
  @moduledoc """
  The deterministic, catalogue-grounded guide behind Chyllz AI.

  This module makes the assistant useful with **zero external dependencies**:
  it reads the same active listings the Chyllz pages render, understands the
  common travel intents (stays, trips, events, cars, food, buses, budgets and
  receipts) and answers with real names, towns and prices plus links into the
  catalogue.

  It is also the automatic fallback whenever the optional AI provider is not
  configured, times out or returns an error, so the chat never goes silent and
  never invents a venue or price.
  """

  alias Xpressbus.TravelAssistant.{FoodGuide, Money, Receipt}

  @static_locations [
    "Nairobi",
    "Mombasa",
    "Diani",
    "Diani Beach",
    "Kisumu",
    "Naivasha",
    "Nakuru",
    "Lamu",
    "Malindi",
    "Watamu",
    "Kilifi",
    "Eldoret",
    "Nanyuki",
    "Nyeri",
    "Kericho",
    "Kitale",
    "Thika",
    "Machakos",
    "Kajiado",
    "Narok",
    "Bomet",
    "Kisii",
    "Kakamega",
    "Bungoma",
    "Busia",
    "Homa Bay",
    "Migori",
    "Isiolo",
    "Meru",
    "Embu",
    "Voi",
    "Taveta",
    "Lodwar",
    "Marsabit",
    "Zanzibar",
    "Arusha",
    "Dar es Salaam",
    "Kampala",
    "Jinja",
    "Entebbe",
    "Kigali"
  ]

  @stopwords ~w(the and for with that this from have has are you your what where when which how can could would should find show tell need want looking look something good best nice great please near around about like just some any into over under)

  # Regexes are built inside a function rather than stored in a module
  # attribute: the `%Regex{}` struct keeps a compiled reference that Elixir
  # 1.18 (the production runtime) cannot escape from module attributes.
  defp budget_regexes do
    [
      ~r/(?:under|below|less than|max(?:imum)?|up to|budget(?: of)?|around|for)\s*(?:ksh|kes)?\s*([\d][\d,]*(?:\.\d+)?)\s*(k)?/i,
      ~r/(?:ksh|kes)\s*([\d][\d,]*(?:\.\d+)?)\s*(k)?/i,
      ~r/([\d][\d,]*(?:\.\d+)?)\s*(k)?\s*(?:ksh|kes)/i
    ]
  end

  @doc """
  Answers a typed message for a tab. Returns a reply map with `:text`, `:cards`
  and an optional `:action`.
  """
  def answer(tab, prompt, context, history \\ [])

  def answer("food", prompt, context, history) do
    food_reply(prompt, context, history)
  end

  def answer(tab, prompt, context, history) when tab in ["chat", "lens", "receipt"] do
    normalized = normalize(prompt)
    location = find_location(prompt, context, history)
    budget = find_budget(prompt)

    cond do
      normalized == "" ->
        reply("Tell me what you're planning and I'll take it from there.")

      greeting_message?(normalized) ->
        greeting("chat")

      thanks?(normalized) ->
        reply(
          "Karibu! 🌍 Happy to help. Want a stay, an event, a car or a food plan next?",
          []
        )

      receipt?(normalized) ->
        reply(
          """
          I can turn a receipt into a clean spend log. Open the Receipt tab, snap a photo or paste the lines like this:

          Chapati 120
          Tilapia 850
          Total 970

          I'll total it, sort it into Food / Transport / Stay / Activities and keep a running trip total.
          """,
          [],
          %{label: "Open Receipt tab", tab: "receipt"}
        )

      food?(normalized) ->
        food_reply(prompt, context, history)

      car?(normalized) ->
        car_reply(location, context)

      event?(normalized) ->
        event_reply(location, context)

      hotel?(normalized) ->
        hotel_reply(location, budget, context)

      hidden_gem?(normalized) ->
        gem_reply(location, context)

      trip?(normalized) ->
        trip_reply(location, budget, context)

      bus?(normalized) ->
        bus_reply(location)

      budget != nil ->
        budget_reply(budget, location, context)

      true ->
        search_reply(prompt, context)
    end
  end

  @doc "Welcome message shown when a tab has no messages yet."
  def greeting(tab) do
    case tab do
      "chat" ->
        reply(
          """
          Hi there! I'm Chyllz — your AI travel companion for East Africa. 🧭

          I can plan a trip, find a stay, suggest food, find events or read a receipt. Where are you headed?
          """,
          []
        )

      "lens" ->
        reply(
          """
          Drop a photo of a place, view or stay — or describe the vibe — and I'll match it to real Chyllz picks.

          Try “beach villa”, “bush lodge” or “city nightlife”.
          """,
          []
        )

      "receipt" ->
        reply(
          """
          Snap a receipt or paste its lines. I'll total it, sort it into categories and keep a running trip-spend log for you.
          """,
          []
        )

      "food" ->
        reply(
          """
          Tell me where you are and what you're craving — I'll suggest local dishes and Chyllz picks nearby.

          Try “street food in Mombasa”, “vegetarian in Nairobi” or “seafood in Diani”.
          """,
          []
        )

      _other ->
        reply("Hi! How can I help with your trip?", [])
    end
  end

  @doc "Quick prompts shown under the tab greeting."
  def suggestions(tab) do
    case tab do
      "chat" ->
        [
          "Plan a 3-day trip to Diani",
          "Best hotels under KES 10,000",
          "What's on this month?",
          "Family-friendly weekend ideas"
        ]

      "lens" ->
        [
          "Find stays with a beach view",
          "Match this vibe to a hidden gem",
          "A cosy city weekend"
        ]

      "receipt" ->
        [
          "How does the receipt log work?",
          "Ideas to cut trip spending",
          "What counts as trip spend?"
        ]

      "food" ->
        [
          "Street food in Mombasa",
          "Vegetarian food in Nairobi",
          "Seafood in Diani",
          "Nyama choma near Naivasha"
        ]

      _other ->
        []
    end
  end

  @doc """
  Local fallback for the Lens tab when no vision provider is available: matches
  the traveller's description against the live catalogue.
  """
  def photo_reply(caption, context) do
    caption = String.trim(to_string(caption || ""))

    if caption == "" do
      reply(
        """
        Tell me what stands out in the photo — beach, bush, city, food or a hotel style — and I'll match it to Chyllz picks.

        You can also just tap one of the ideas below.
        """,
        top_picks(context, 2)
      )
    else
      search_reply(caption, context, "From your note")
    end
  end

  @doc "True when the prompt is a short greeting (used by the LiveView for shortcuts)."
  def greeting?(prompt), do: prompt |> normalize() |> greeting_message?()

  defp greeting_message?(normalized) do
    Regex.match?(
      ~r/^(hi|hello|hey|habari|jambo|sasa|mambo|good (morning|afternoon|evening)|howdy)\b/,
      normalized
    )
  end

  # --- intents ---------------------------------------------------------------

  defp hotel_reply(location, budget, context) do
    hotels = context[:hotels] || []

    filtered =
      hotels
      |> filter_location(location)
      |> filter_budget(budget)

    cond do
      filtered != [] ->
        scope = scope_phrase(location)
        budget_note = budget_note(budget)

        reply(
          """
          #{if(location, do: "Best stays in #{location}:", else: "A few standout stays:")}#{budget_note}

          #{bullets(filtered |> Enum.take(3) |> Enum.map(&hotel_line/1))}

          Want me to pair one with a hidden gem or an event?
          """,
          filtered |> Enum.take(3) |> Enum.map(&hotel_card/1),
          %{label: "Browse all stays#{scope}", href: stays_path(location)}
        )

      hotels == [] ->
        reply(
          "The Chyllz stay collection is being refreshed right now, so there are no active hotels to show. Try the bus search in the meantime.",
          []
        )

      true ->
        reply(
          """
          I don't see an active Chyllz stay#{if(location, do: " in #{location}", else: "")}#{if(budget, do: " under KES #{Money.format(budget)}", else: "")} right now.

          Try a higher budget or another town — or browse the full collection.
          """,
          hotels |> Enum.take(2) |> Enum.map(&hotel_card/1),
          %{label: "Browse all stays", href: "/tour-packages/hotels"}
        )
    end
  end

  defp gem_reply(location, context) do
    gems = context[:hidden_gems] || []
    filtered = filter_location(gems, location)
    picks = if(filtered == [], do: gems, else: filtered) |> Enum.take(3)

    if picks == [] do
      reply(
        "The hidden-gem collection is being refreshed. Ask me for a stay or an event instead.",
        []
      )
    else
      title =
        if filtered == [] and location,
          do: "No exact hidden gems in #{location} yet — here are a few worth the detour:",
          else:
            if(location,
              do: "Hidden gems around #{location}:",
              else: "A few hidden gems worth the detour:"
            )

      reply(
        title <>
          "\n\n" <>
          bullets(Enum.map(picks, &gem_line/1)) <> "\n\nWhich one should I build a day around?",
        Enum.map(picks, &gem_card/1),
        %{label: "Explore all hidden gems", href: "/our-packages/hidden-gems"}
      )
    end
  end

  defp car_reply(location, context) do
    cars = context[:car_hires] || []
    filtered = filter_location(cars, location)
    picks = if(filtered == [], do: cars, else: filtered) |> Enum.take(3)

    if picks == [] do
      reply("No vehicles are listed right now. Please check the car-hire page shortly.", [])
    else
      title =
        if location,
          do: "Car hire options in #{location}:",
          else: "Self-drive and chauffeured options:"

      reply(
        title <>
          "\n\n" <>
          bullets(Enum.map(picks, &car_line/1)) <>
          "\n\nTell me your dates and I can suggest how many days you'll need.",
        Enum.map(picks, &car_card/1),
        %{label: "Browse car hire", href: "/tour-packages/car"}
      )
    end
  end

  defp event_reply(location, context) do
    events = context[:events] || []
    filtered = filter_location(events, location)
    picks = if(filtered == [], do: events, else: filtered) |> Enum.take(3)

    if picks == [] do
      reply(
        "There are no upcoming Chyllz events listed right now. Want a stay or a hidden gem instead?",
        []
      )
    else
      title =
        if is_binary(location) and filtered != [],
          do: "Coming up in #{location}:",
          else: "Coming up on Chyllz:"

      reply(
        title <>
          "\n\n" <>
          bullets(Enum.map(picks, &event_line/1)) <>
          "\n\nWant me to add a nearby stay for the night?",
        Enum.map(picks, &event_card/1),
        %{label: "See all events", href: "/tour-packages/events"}
      )
    end
  end

  defp trip_reply(nil, _budget, context) do
    reply(
      """
      I'd love to plan that. Which town or region are you thinking of — Diani, Naivasha, Nairobi, Mombasa, Lamu…?

      Or tell me the kind of trip: beach, bush, city weekend or family break.
      """,
      top_picks(context, 2)
    )
  end

  defp trip_reply(location, budget, context) do
    hotels = (context[:hotels] || []) |> filter_location(location)
    gems = (context[:hidden_gems] || []) |> filter_location(location)
    events = (context[:events] || []) |> filter_location(location)
    cars = (context[:car_hires] || []) |> filter_location(location)

    hotels = if budget, do: filter_budget(hotels, budget), else: hotels

    hotel = best_hotel(hotels)
    gem = List.first(gems)
    event = List.first(events)
    car = List.first(cars)
    dishes = FoodGuide.suggestions(location, [], 2)

    if hotel == nil and gem == nil and event == nil do
      reply(
        """
        I don't have active Chyllz listings in #{location} yet — but here are a few outstanding picks to build a trip around:

        #{bullets(Enum.map(top_picks(context, 3), &card_line/1))}

        Tell me which one appeals and I'll shape the days.
        """,
        top_picks(context, 3)
      )
    else
      days = build_itinerary(location, hotel, gem, event, car, dishes)

      reply(
        "Here's a three-day Chyllz plan for #{location}:\n\n" <>
          days <>
          "\n\nBook the bus to #{location} on KOMIUTA, then reserve the stay from Chyllz. Want a cheaper version or more days?",
        [hotel, gem, event, car]
        |> Enum.reject(&is_nil/1)
        |> Enum.take(3)
        |> Enum.map(&any_card/1),
        %{label: "Search buses to #{location}", href: bus_path(location)}
      )
    end
  end

  defp build_itinerary(location, hotel, gem, event, car, dishes) do
    [
      "Day 1 — Arrive and settle in",
      hotel && "• Stay: #{hotel_summary(hotel)}",
      gem && "• Easy explore: #{gem_summary(gem)}",
      "",
      "Day 2 — The main experience",
      gem && "• Dive deeper: #{gem_summary(gem)}",
      dishes != [] && "• Eat local: #{dishes |> Enum.map(& &1.name) |> Enum.join(", ")}",
      car && "• Getting around: #{car_summary(car)}",
      "",
      "Day 3 — Slow morning and head home",
      event && "• If the dates line up: #{event_summary(event)}",
      "• Leave a buffer for the bus back to #{location} and confirm your pickup point."
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp bus_reply(nil) do
    reply(
      """
      KOMIUTA books bus tickets across Kenya and East Africa. Search your route on the home page — or tell me your origin and destination and I'll point you the right way.

      Once your ticket is set, I can add a stay, event or car to the trip.
      """,
      [],
      %{label: "Search buses", href: bus_path(nil)}
    )
  end

  defp bus_reply(location) do
    reply(
      """
      You can book a bus to #{location} right on KOMIUTA — enter “To: #{location}” in the search pill and pick your date.

      Want me to pair it with a stay or an event in #{location}?
      """,
      [],
      %{label: "Search buses to #{location}", href: bus_path(location)}
    )
  end

  defp budget_reply(budget, location, context) do
    hotels =
      (context[:hotels] || [])
      |> filter_budget(budget)
      |> filter_location(location)
      |> Enum.take(2)

    cars =
      (context[:car_hires] || [])
      |> filter_budget(budget)
      |> filter_location(location)
      |> Enum.take(1)

    picks = hotels ++ cars

    reply(
      """
      With KES #{Money.format(budget)} to play with, here's how I'd use it#{if(location, do: " in #{location}", else: "")}:

      #{if picks == [], do: "• The active catalogue has nothing under that budget right now — try a slightly higher amount.", else: bullets(Enum.map(picks, &card_line/1))}

      Keep a little aside for food and local transport — that's usually 20–30% of a short trip.
      """,
      Enum.map(picks, &any_card/1),
      %{label: "Browse the catalogue", href: "/tour-packages"}
    )
  end

  defp search_reply(prompt, context, prefix \\ nil) do
    matches = search(context, prompt, 3)

    if matches == [] do
      reply(
        """
        #{prefix || "I didn't find an exact catalogue match for that."} I can still help with:

        • Stays, hidden gems, car hire and events
        • A day-by-day trip plan
        • Food by destination and diet
        • Receipt totals and trip spend

        Try “hotels under KES 10,000 in Nairobi” or “what's on in Naivasha?”.
        """,
        top_picks(context, 2)
      )
    else
      cards = Enum.map(matches, &any_card/1)

      reply(
        """
        #{prefix || "Here's what matches closest in the live Chyllz catalogue:"}

        #{bullets(Enum.map(cards, &card_line/1))}

        Want details or a plan around one of these?
        """,
        cards,
        %{label: "Browse everything", href: "/tour-packages"}
      )
    end
  end

  defp food_reply(prompt, context, history) do
    normalized = normalize(prompt)

    location =
      find_location(prompt, context, history) || most_common_location(context) || "Nairobi"

    preferences = food_preferences(normalized)
    dishes = FoodGuide.suggestions(location, preferences, 4)
    region = FoodGuide.region_label(FoodGuide.region_for(location))

    nearby =
      context
      |> then(fn ctx ->
        filter_location(ctx[:hidden_gems] || [], location) ++
          filter_location(ctx[:hotels] || [], location)
      end)
      |> Enum.take(2)
      |> Enum.map(&any_card/1)

    diet_note =
      cond do
        Enum.any?(preferences, &String.starts_with?(&1, "veget")) or "vegan" in preferences ->
          "I've kept the list vegetarian-friendly."

        "seafood" in preferences ->
          "I've leaned into seafood."

        true ->
          "Tell me if you're vegetarian, vegan or after seafood and I'll narrow it down."
      end

    budget_note =
      cond do
        String.contains?(normalized, ["cheap", "street", "budget", "affordable"]) ->
          "Street food and casual local spots will stretch your budget furthest."

        String.contains?(normalized, ["fine dining", "nice", "romantic", "special"]) ->
          "For a nicer sit-down meal, pick a hotel with a restaurant and ask about their grill or seafood night."

        true ->
          ""
      end

    dish_lines =
      dishes
      |> Enum.map(fn dish -> "• #{dish.name} — #{dish.note}" end)
      |> Enum.join("\n")

    text =
      """
      Flavours to look for in #{location} (#{region}):

      #{dish_lines}

      #{diet_note} #{budget_note}
      """

    reply(
      String.trim(text),
      nearby,
      %{label: "Explore Chyllz nearby", href: "/our-packages/hidden-gems"}
    )
  end

  # --- catalogue helpers -----------------------------------------------------

  defp best_hotel([]), do: nil
  defp best_hotel(hotels), do: Enum.max_by(hotels, &rating_value/1, fn -> List.first(hotels) end)

  defp rating_value(hotel), do: hotel.rating |> Money.to_decimal() |> Decimal.to_float()

  defp filter_location(items, nil), do: items

  defp filter_location(items, location) do
    location = String.downcase(location)

    Enum.filter(items, fn item ->
      item_location(item)
      |> to_string()
      |> String.downcase()
      |> String.contains?(location)
    end)
  end

  defp filter_budget(items, nil), do: items

  defp filter_budget(items, budget) do
    Enum.filter(items, fn item ->
      case item_price(item) do
        nil -> true
        price -> Decimal.compare(Money.to_decimal(price), budget) != :gt
      end
    end)
  end

  defp item_location(item) do
    Map.get(item, :location) || Map.get(item, :town) || ""
  end

  defp item_price(%{price_per_night: price}), do: price
  defp item_price(%{price_per_day: price}), do: price
  defp item_price(_item), do: nil

  defp most_common_location(context) do
    (context[:hotels] || [])
    |> Enum.map(& &1.location)
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.max_by(fn {_location, count} -> count end, fn -> nil end)
    |> case do
      nil -> nil
      {location, _count} -> location
    end
  end

  @doc "Finds a known destination in a prompt (falls back to the recent thread)."
  def find_location(prompt, context, history \\ []) do
    candidates = location_candidates(context)

    direct =
      candidates
      |> Enum.sort_by(&String.length/1, :desc)
      |> Enum.find(fn location ->
        Regex.match?(~r/\b#{Regex.escape(String.downcase(location))}\b/, String.downcase(prompt))
      end)

    direct || find_location_in_history(history, candidates)
  end

  defp find_location_in_history(history, candidates) do
    history
    |> Enum.filter(&(&1.role == :user))
    |> Enum.take(-4)
    |> Enum.reverse()
    |> Enum.find_value(fn message ->
      text = String.downcase(message.text)

      candidates
      |> Enum.sort_by(&String.length/1, :desc)
      |> Enum.find(fn location ->
        Regex.match?(~r/\b#{Regex.escape(String.downcase(location))}\b/, text)
      end)
    end)
  end

  defp location_candidates(context) do
    from_context =
      [:hotels, :hidden_gems, :car_hires, :events]
      |> Enum.flat_map(fn key ->
        (context[key] || [])
        |> Enum.map(&item_location/1)
        |> Enum.flat_map(fn location ->
          if is_binary(location) do
            [location | String.split(location, ",")]
          else
            []
          end
        end)
      end)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == "" or String.length(&1) < 3))

    Enum.uniq(@static_locations ++ from_context)
  end

  @doc "Extracts a KES budget from free text."
  def find_budget(prompt) when is_binary(prompt) do
    Enum.find_value(budget_regexes(), fn regex ->
      case Regex.run(regex, prompt, capture: :all_but_first) do
        [amount] -> budget_from_parts(amount, nil)
        [amount, k] -> budget_from_parts(amount, k)
        _other -> nil
      end
    end)
  end

  def find_budget(_prompt), do: nil

  defp budget_from_parts(amount, k) do
    value = Money.to_decimal(amount)
    value = if k in ["k", "K"], do: Decimal.mult(value, 1000), else: value

    if Decimal.compare(value, 500) == :lt do
      nil
    else
      value
    end
  end

  # --- matching --------------------------------------------------------------

  defp search(context, query, limit) do
    tokens = keywords(query)

    items =
      (context[:hotels] || []) ++
        (context[:hidden_gems] || []) ++
        (context[:car_hires] || []) ++
        (context[:events] || [])

    items
    |> Enum.map(fn item ->
      haystack =
        [title(item), item_location(item), Map.get(item, :description), Map.get(item, :type)]
        |> Enum.reject(&is_nil/1)
        |> Enum.join(" ")
        |> String.downcase()

      score = Enum.count(tokens, &String.contains?(haystack, &1))
      {score, item}
    end)
    |> Enum.filter(fn {score, _item} -> score > 0 end)
    |> Enum.sort_by(fn {score, item} -> {-score, title(item)} end)
    |> Enum.take(limit)
    |> Enum.map(fn {_score, item} -> item end)
  end

  defp keywords(text) do
    text
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/, " ")
    |> String.split()
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(String.length(&1) < 3 or &1 in @stopwords))
    |> Enum.uniq()
    |> Enum.take(8)
  end

  defp top_picks(context, limit) do
    (context[:hotels] || [])
    |> Enum.take(limit)
    |> Enum.map(&any_card/1)
    |> case do
      [] -> (context[:hidden_gems] || []) |> Enum.take(limit) |> Enum.map(&any_card/1)
      cards -> cards
    end
  end

  # --- formatting ------------------------------------------------------------

  defp reply(text, cards \\ [], action \\ nil) do
    %{
      text: String.trim(text),
      cards: cards,
      action: action
    }
  end

  defp bullets(lines), do: Enum.join(lines, "\n")

  defp scope_phrase(nil), do: ""
  defp scope_phrase(location), do: " in #{location}"

  defp budget_note(nil), do: ""
  defp budget_note(budget), do: " (under KES #{Money.format(budget)})"

  defp hotel_line(hotel), do: "• " <> hotel_summary(hotel)

  defp hotel_summary(hotel) do
    rating = if hotel.rating, do: " · #{rating_text(hotel.rating)}★", else: ""

    "#{hotel.name} — #{hotel.location} — KES #{Money.format(hotel.price_per_night)}/night#{rating}"
  end

  defp gem_line(gem), do: "• " <> gem_summary(gem)
  defp gem_summary(gem), do: "#{gem.title} — #{gem.location}"

  defp car_line(car), do: "• " <> car_summary(car)

  defp car_summary(car) do
    "#{car.car_name} (#{car.type}) — #{car.location || "Kenya"} — KES #{Money.format(car.price_per_day)}/day"
  end

  defp event_line(event), do: "• " <> event_summary(event)

  defp event_summary(event) do
    date = if event.date, do: Calendar.strftime(event.date, "%-d %b"), else: "TBA"
    "#{event.title} — #{event.location} — #{date}"
  end

  defp card_line(card),
    do: "• #{card.title} — #{card.subtitle}#{if card.price, do: " — #{card.price}", else: ""}"

  defp title(%{name: name}), do: name
  defp title(%{title: title}), do: title
  defp title(%{car_name: name}), do: name
  defp title(_item), do: ""

  defp rating_text(rating) do
    rating
    |> Money.to_decimal()
    |> Decimal.round(1)
    |> Decimal.to_string(:normal)
  end

  # Cards are plain maps rendered by the assistant component.
  defp hotel_card(hotel) do
    %{
      kind: "hotel",
      title: hotel.name,
      subtitle:
        "#{hotel.location}#{if hotel.rating, do: " · #{rating_text(hotel.rating)}★", else: ""}",
      price: "KES #{Money.format(hotel.price_per_night)} / night",
      image: image_for(hotel, 1),
      href: "/tour-packages/hotels?q=" <> URI.encode_www_form(hotel.name)
    }
  end

  defp gem_card(gem) do
    %{
      kind: "hidden_gem",
      title: gem.title,
      subtitle: gem.location,
      price: nil,
      image: image_for(gem, 2),
      href: "/our-packages/hidden-gems?q=" <> URI.encode_www_form(gem.title)
    }
  end

  defp car_card(car) do
    %{
      kind: "car_hire",
      title: car.car_name,
      subtitle: "#{car.type} · #{car.location || "Kenya"}",
      price: "KES #{Money.format(car.price_per_day)} / day",
      image: nil,
      href: "/tour-packages/car?q=" <> URI.encode_www_form(car.car_name)
    }
  end

  defp event_card(event) do
    %{
      kind: "event",
      title: event.title,
      subtitle:
        "#{event.location}#{if event.date, do: " · " <> Calendar.strftime(event.date, "%-d %b"), else: ""}",
      price: nil,
      image: image_for(event, 3),
      href: "/tour-packages/events?q=" <> URI.encode_www_form(event.title)
    }
  end

  defp any_card(%{name: _name} = hotel), do: hotel_card(hotel)
  defp any_card(%{car_name: _name} = car), do: car_card(car)
  defp any_card(%{title: _title, date: _date} = event), do: event_card(event)
  defp any_card(%{title: _title} = gem), do: gem_card(gem)
  defp any_card(_other), do: nil

  defp image_for(item, fallback_index) do
    case List.first(Map.get(item, :images) || []) do
      nil -> "/images/room_#{fallback_index}.webp"
      path when is_binary(path) -> normalize_image(path)
      _other -> "/images/room_#{fallback_index}.webp"
    end
  end

  defp normalize_image(path) do
    if String.starts_with?(path, ["http://", "https://", "/"]), do: path, else: "/images/" <> path
  end

  defp stays_path(nil), do: "/tour-packages/hotels"
  defp stays_path(location), do: "/tour-packages/hotels?q=" <> URI.encode_www_form(location)

  defp bus_path(nil), do: "/"
  defp bus_path(location), do: "/?" <> URI.encode_query(%{"to" => location})

  # --- intent detection ------------------------------------------------------

  defp normalize(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\S\n]+/, " ")
    |> String.trim()
  end

  defp normalize(_text), do: ""

  defp thanks?(normalized) do
    Regex.match?(
      ~r/^(thanks|thank you|asante|shukran|perfect|awesome|great|nice)[!. ]*$/,
      normalized
    )
  end

  defp receipt?(normalized) do
    Regex.match?(
      ~r/\b(receipts?|expenses?|spent|spend|budget track|reimburs\w*|invoices?)\b/,
      normalized
    )
  end

  defp food?(normalized) do
    Regex.match?(
      ~r/\b(foods?|eat|eating|restaurants?|cuisines?|dishes?|breakfast|brunch|lunch|dinner|vegetarian|vegan|seafood|nyama|street food|coffee|drinks?)\b/,
      normalized
    )
  end

  defp car?(normalized) do
    Regex.match?(
      ~r/\b(cars?|vehicles?|drive|hire|rental?|transfer|driver|4x4|suv|prado|van)\b/,
      normalized
    )
  end

  defp event?(normalized) do
    Regex.match?(
      ~r/\b(events?|festivals?|concerts?|part(?:y|ies)|what'?s on|happening|this weekend|things to do|activities|activity)\b/,
      normalized
    )
  end

  defp hotel?(normalized) do
    Regex.match?(
      ~r/\b(hotels?|stays?|rooms?|accommodations?|sleep|resorts?|lodges?|apartments?|guesthouses?|nights?)\b/,
      normalized
    )
  end

  defp hidden_gem?(normalized) do
    Regex.match?(
      ~r/\b(hidden gems?|off the beaten|secrets?|adventures?|explore|nature|hikes?|hiking|beach(?:es)?|waterfalls?)\b/,
      normalized
    )
  end

  defp trip?(normalized) do
    Regex.match?(
      ~r/\b(plans?|itinerar(?:y|ies)|trips?|holidays?|vacations?|weekends?|getaways?|day trip|honeymoons?)\b/,
      normalized
    )
  end

  defp bus?(normalized) do
    Regex.match?(
      ~r/\b(buses?|tickets?|travel to|get to|transport|matatus?|shuttles?|routes?)\b/,
      normalized
    )
  end

  defp food_preferences(normalized) do
    []
    |> maybe_add("vegetarian", String.contains?(normalized, "vegetarian"))
    |> maybe_add("vegan", String.contains?(normalized, "vegan"))
    |> maybe_add("seafood", String.contains?(normalized, "seafood"))
    |> maybe_add("halal", String.contains?(normalized, "halal"))
  end

  defp maybe_add(list, value, true), do: list ++ [value]
  defp maybe_add(list, _value, false), do: list

  @doc "Formats a parsed receipt summary mention for the chat fallback."
  def receipt_suggestion(summary) do
    Receipt.summary_text(summary)
  end
end
