defmodule Xpressbus.TripItinerary do
  @moduledoc """
  Builds the rich, display-ready itinerary shown after the AI trip builder runs.

  The builder collects destination, dates, companions, budget and preferences; this
  module turns that brief into the sections the result page renders: title, overview,
  hotel and food guidance, recommended restaurants, a day-by-day plan and important
  travel notes. The Moscow sample follows the curated reference itinerary; other
  destinations receive the same structure with destination-aware copy.
  """

  @restaurants [
    "Classic Rice Table Dine",
    "Heritage Seafood House Cafe",
    "Flaming Rice Corner Grill",
    "Urban Pizza Grill",
    "Flaming Fast Food Cafe Restaurant",
    "Tasty Thai Kitchenette Dine",
    "Red Seafood Diner Grill",
    "Chef's Pizza Bistro Cafe"
  ]

  @restaurant_images [
    "/images/room_1.webp",
    "/images/room_2.webp",
    "/images/room_3.webp",
    "/images/chyllz_hero.png",
    "/images/chyllz_account_hero.webp",
    "/images/hero_bg-640.webp",
    "/images/room_1.webp",
    "/images/room_2.webp"
  ]

  @moscow_days [
    %{
      title: "Moscow City Center & Red Square",
      morning:
        "Arrive at Moscow International Airport and take a private luxury transfer to your hotel. Check in, settle into your room and enjoy a leisurely breakfast in the hotel's exclusive dining area.",
      lunch:
        "Indulge in a sophisticated lunch at a renowned restaurant close to your hotel, a perfect introduction to the city's fine dining scene.",
      afternoon:
        "Join a private guided tour of Red Square. See St. Basil's Cathedral, the GUM department store and the State Historical Museum while your guide brings centuries of history to life.",
      evening:
        "Take a romantic evening stroll through Zaryadye Park and its floating bridge, with panoramic views over the Moscow River and the Kremlin.",
      dinner:
        "Enjoy an unforgettable dinner at a high-end restaurant with rooftop or panoramic city views, a perfect blend of culinary excellence and romance."
    },
    %{
      title: "Moscow Kremlin & Art District",
      morning:
        "Start with a sumptuous breakfast at your hotel, then take a private transfer to the Tretyakov Gallery for a guided tour of Russia's finest collection of art.",
      lunch:
        "Stop for a gourmet lunch in the artistic Zamoskvorechye district, known for its historic architecture and modern Russian and European menus.",
      afternoon:
        "Explore the Moscow Kremlin with a private guide: its cathedrals, the Grand Kremlin Palace and the Armory Chamber's dazzling collection of imperial treasures.",
      evening:
        "See the city from a different perspective on a luxurious evening cruise along the Moscow River, gliding past illuminated landmarks.",
      dinner:
        "Conclude with an exquisite dinner at a celebrated modern Russian restaurant, known for inventive dishes and impeccable service."
    },
    %{
      title: "Kolomenskoye Estate & Bolshoi Theatre",
      morning:
        "After breakfast, escape to the UNESCO-listed Kolomenskoye Estate for a private tour of its historic churches, wooden palace and parklands. Adventurous travellers can arrange a private horse-riding session nearby.",
      lunch:
        "Enjoy a refined lunch at a countryside restaurant near Kolomenskoye, offering traditional Russian fare in a scenic setting.",
      afternoon:
        "Return to the city for a couple's spa treatment at your hotel or browse Moscow's high-end boutiques and department stores.",
      evening:
        "Prepare for an unforgettable evening at the legendary Bolshoi Theatre, with a world-class ballet or opera performance (subject to availability).",
      dinner:
        "After the performance, enjoy a sophisticated late dinner at an elegant restaurant close to the Bolshoi, perfect for discussing the evening's spectacle."
    },
    %{
      title: "Moscow Departure",
      morning:
        "Savour a final breakfast at your hotel and enjoy a leisurely morning of last-minute souvenir shopping or a visit to the Pushkin Museum of Fine Arts.",
      lunch:
        "Indulge in a farewell lunch at a favourite restaurant or discover a new culinary gem before your journey home.",
      afternoon:
        "Relax at your hotel before a private luxury transfer takes you to Moscow International Airport in comfort.",
      evening:
        "Unwind in the airport's VIP lounge and reflect on the memories created during your luxury Moscow escape.",
      dinner:
        "Enjoy a light dinner or refreshments during your transfer or in the executive lounge before your evening flight."
    }
  ]

  @moscow_notes [
    %{
      title: "Visa Requirements",
      text:
        "Ensure all necessary visa requirements for Russia are fulfilled well in advance. Consult the Russian embassy or consulate in your home country for current procedures."
    },
    %{
      title: "Local Currency",
      text:
        "The local currency is the Russian Ruble (RUB). Credit cards are widely accepted in luxury establishments, but carry some cash for smaller purchases and exchange at reputable banks or your hotel."
    },
    %{
      title: "Language Barrier",
      text:
        "Russian is the official language. Staff in luxury hotels and high-end restaurants often speak English; a translation app or phrasebook is useful for street navigation."
    },
    %{
      title: "Cultural Etiquette",
      text:
        "When visiting churches, women should cover their heads and shoulders and everyone should dress modestly. Avoid loud conversations in sacred places and respect photography restrictions."
    },
    %{
      title: "Booking In Advance",
      text:
        "For luxury travel, book Bolshoi tickets, private tours and high-demand restaurants several weeks or months ahead to secure availability."
    },
    %{
      title: "Personal Safety",
      text:
        "Moscow is generally safe for tourists, but stay aware of your surroundings in crowded areas. Keep valuables secure and use reputable transport arranged through your hotel concierge."
    },
    %{
      title: "Transportation",
      text:
        "Use private car services for maximum comfort. Moscow's metro is beautiful and efficient, but private transfers make exploring the city effortless."
    }
  ]

  @doc "Builds the display-ready itinerary for a trip brief."
  def generate(trip) do
    city = city_label(trip)
    moscow? = moscow?(trip)

    %{
      title: title(trip),
      city: city,
      map_url: map_url(city),
      overview: overview(trip, moscow?),
      hotel: hotel_recommendation(trip, moscow?),
      food: food_recommendation(trip, moscow?),
      restaurants: restaurants(),
      days: days(trip, moscow?),
      notes: notes(trip, moscow?)
    }
  end

  defp title(trip) do
    destination = destination(trip)

    "#{destination} Grandeur: #{party_title(trip)} #{budget_title(trip)} Escape"
  end

  defp city_label(trip) do
    country = to_string(trip.country || "")

    if country == "" do
      destination(trip)
    else
      "#{destination(trip)}, #{country}"
    end
  end

  defp map_url(city) do
    "https://maps.google.com/maps?q=#{URI.encode_www_form(city)}&z=11&output=embed"
  end

  defp destination(trip) do
    value = to_string(trip.destination || "")

    if value == "", do: "Your dream destination", else: value
  end

  defp moscow?(trip), do: String.downcase(destination(trip)) =~ "moscow"

  defp party_title(trip) do
    case trip.travel_party do
      "solo" -> "A Solo"
      "couple" -> "A Couple's"
      "family" -> "A Family"
      "friends" -> "A Friends'"
      _other -> "A Personal"
    end
  end

  defp party_label(trip) do
    case trip.travel_party do
      "solo" -> "a solo traveller"
      "couple" -> "a couple"
      "family" -> "a family"
      "friends" -> "a group of friends"
      _other -> "you"
    end
  end

  defp budget_title(trip) do
    case trip.budget do
      "cheap" -> "Budget"
      "balanced" -> "Balanced"
      "luxury" -> "Luxury"
      "flexible" -> "Flexible"
      "custom" -> "Custom"
      "mars" -> "Cosmic"
      _other -> "Personalised"
    end
  end

  defp budget_descriptor(trip) do
    case trip.budget do
      "cheap" -> "budget-friendly, economical travel"
      "balanced" -> "balanced, comfortable spending"
      "luxury" -> "high-end, indulgent experiences"
      "flexible" -> "a flexible approach with no budget restrictions"
      "custom" -> "a custom-tailored budget"
      "mars" -> "an out-of-this-world adventure"
      _other -> "a thoughtfully planned budget"
    end
  end

  defp preferences_label(trip) do
    case trip.preferences do
      [] -> "varied local experiences"
      preferences -> Enum.join(preferences, ", ")
    end
  end

  defp day_count(trip) do
    case {trip.start_date, trip.end_date} do
      {%Date{} = start_date, %Date{} = end_date} ->
        (Date.diff(end_date, start_date) + 1) |> max(1)

      _other ->
        4
    end
  end

  defp overview(trip, true) do
    duration = day_count(trip)

    """
    Embark on an opulent #{duration}-day journey through Moscow, designed for #{party_label(trip)} seeking \
    unparalleled luxury, deep cultural immersion and sophisticated experiences. This itinerary balances \
    iconic city landmarks with exclusive art encounters, serene nature escapes and exquisite culinary \
    adventures. From private guided tours of the Kremlin and Red Square to a romantic river cruise and an \
    evening at the Bolshoi Theatre, every moment is crafted for comfort and enrichment. You will delve into \
    Russia's rich history, marvel at its artistic masterpieces and savour gourmet dining experiences that \
    showcase the best of Russian and international cuisine. This trip blends city exploration, relaxing \
    moments and unique activities such as horse riding, catering to a range of luxury interests and \
    ensuring unforgettable memories.
    """
  end

  defp overview(trip, false) do
    duration = day_count(trip)

    """
    Discover #{destination(trip)} on a #{duration}-day #{budget_title(trip) |> String.downcase()} escape \
    crafted for #{party_label(trip)}. This itinerary combines the city's signature landmarks, authentic \
    local culture and carefully chosen food and stay recommendations around your love of \
    #{preferences_label(trip)}. Each day balances guided exploration with free time to relax, so the trip \
    feels rich without being rushed. From your arrival transfer to the final dinner, everything is arranged \
    around #{budget_descriptor(trip)}, with memorable stops for art, nature, shopping and local life along \
    the way.
    """
  end

  defp hotel_recommendation(trip, true) do
    """
    For a luxury trip to Moscow, select a hotel in the heart of the city, particularly near Red Square or \
    the Tverskaya Street area. This strategic location offers unparalleled access to major attractions, \
    high-end shopping and fine dining, making it ideal for #{party_label(trip)} desiring convenience and \
    sophistication. Look for properties that offer exceptional concierge services, private car transfers \
    and exclusive amenities such as a luxury spa, indoor pool or a gourmet restaurant with panoramic city \
    views. Prioritise hotels known for their historical grandeur combined with modern comforts. Book well \
    in advance, especially around major events or peak seasons, to secure the best suites and rates. \
    Personalised experiences such as private butlers or tailored tour arrangements make the stay truly \
    indulgent.
    """
  end

  defp hotel_recommendation(trip, false) do
    """
    Choose a stay in a central, well-connected neighbourhood of #{destination(trip)}, close to the \
    attractions that matter most for #{preferences_label(trip)}. For #{budget_descriptor(trip)}, look for \
    properties with strong guest reviews, easy access to public transport or private transfers, and \
    thoughtful amenities such as breakfast, reliable Wi-Fi and flexible check-in. Booking early often \
    unlocks better rooms and rates, particularly around local holidays and peak travel periods. A well-located \
    base keeps transfers short and leaves more time for exploring.
    """
  end

  defp food_recommendation(_trip, true) do
    """
    Moscow's culinary scene is a delightful blend of traditional Russian flavours and international gourmet \
    experiences, perfect for food-tourism enthusiasts. Start with classic dishes such as 'Borscht', a vibrant \
    beetroot soup often served with sour cream, and 'Pelmeni', savoury meat-filled dumplings, or 'Vareniki', \
    sweet or savoury stuffed dumplings. Don't miss 'Blini', thin pancakes served with toppings from caviar \
    and smoked salmon to condensed milk and jam. For something hearty, 'Beef Stroganoff' is a must, rich \
    and creamy and often served with mashed potatoes. 'Olivier Salad' is a surprising delight of diced \
    vegetables and meat in mayonnaise. Indulge in Russian black bread, full of flavour, and try 'Kvass', a \
    traditional fermented rye drink, alongside premium Russian vodka or sparkling wine. Luxury dining in \
    Moscow means top-tier restaurants offering elevated interpretations of these classics along with \
    innovative European and Asian fusion cuisine, exquisite presentation, extensive wine lists and \
    impeccable service.
    """
  end

  defp food_recommendation(trip, false) do
    """
    #{destination(trip)} has a rich food scene that rewards travellers who explore beyond the obvious. \
    Seek out neighbourhood restaurants and markets that showcase regional ingredients and family recipes, \
    then balance them with contemporary dining for #{budget_descriptor(trip)}. Your preferences for \
    #{preferences_label(trip)} are a great guide: ask your hotel concierge or local hosts for the dishes, \
    cafés and food streets they recommend. Reserve popular tables in advance and leave room for spontaneous \
    stops — the best meals are often the ones you discover while wandering.
    """
  end

  defp restaurants do
    @restaurants
    |> Enum.with_index()
    |> Enum.map(fn {name, index} ->
      %{
        name: name,
        image: Enum.at(@restaurant_images, index),
        rating: "0.0"
      }
    end)
  end

  defp days(trip, moscow?) do
    start_date = trip.start_date || Date.utc_today()
    count = day_count(trip) |> min(6)

    if moscow? do
      for index <- 0..(count - 1) do
        template = Enum.at(@moscow_days, rem(index, length(@moscow_days)))
        date = Date.add(start_date, index)

        %{
          date: Calendar.strftime(date, "%A, %b %d"),
          title: template.title,
          morning: template.morning,
          lunch: template.lunch,
          afternoon: template.afternoon,
          evening: template.evening,
          dinner: template.dinner
        }
      end
    else
      for index <- 0..(count - 1) do
        date = Date.add(start_date, index)
        destination = destination(trip)

        %{
          date: Calendar.strftime(date, "%A, %b %d"),
          title: generic_day_title(index),
          morning:
            "Start the day with breakfast and a relaxed introduction to #{destination}. Your host will help you plan the route around #{preferences_label(trip)}.",
          lunch:
            "Stop at a well-reviewed local restaurant for a lunch that reflects the region's flavours and your #{budget_descriptor(trip)}.",
          afternoon:
            "Explore #{destination}'s highlights with time for the experiences you enjoy most. Keep the pace comfortable and leave room to discover something unexpected.",
          evening:
            "Wind down with a scenic walk or a quiet drink, then enjoy an evening activity chosen to match your travel style.",
          dinner:
            "End the day with dinner at a recommended restaurant, savouring local specialities in a relaxed setting."
        }
      end
    end
  end

  defp generic_day_title(0), do: "Arrival & First Impressions"
  defp generic_day_title(1), do: "Landmarks & Local Culture"
  defp generic_day_title(2), do: "Nature, Food & Free Time"
  defp generic_day_title(3), do: "Favourite Corners & Farewell"
  defp generic_day_title(_index), do: "Explore & Unwind"

  defp notes(_trip, true), do: @moscow_notes

  defp notes(trip, false) do
    destination = destination(trip)
    currency = to_string(trip.country || "")

    [
      %{
        title: "Travel Documents",
        text:
          "Check entry requirements, visa rules and passport validity for #{destination} well in advance. Keep digital and printed copies of important documents."
      },
      %{
        title: "Local Currency",
        text:
          "Familiarise yourself with the local currency#{if currency == "", do: "", else: " in #{currency}"} and carry a small amount of cash alongside your cards. Exchange at reputable banks or your hotel."
      },
      %{
        title: "Language",
        text:
          "Download an offline translation app before you travel. Learning a few greetings goes a long way with local hosts and restaurant staff."
      },
      %{
        title: "Cultural Etiquette",
        text:
          "Dress respectfully at religious and cultural sites, ask before photographing people and follow local customs around tipping and public behaviour."
      },
      %{
        title: "Book Ahead",
        text:
          "Reserve popular restaurants, guided tours and transport in advance, especially during peak travel periods and local holidays."
      },
      %{
        title: "Safety",
        text:
          "Stay aware of your surroundings, keep valuables secure and use trusted transport. Save your hotel's address and emergency contacts offline."
      },
      %{
        title: "Transport",
        text:
          "Plan transfers between the airport, hotel and main sights. Private transfers or a reliable local ride-hailing app make the trip smoother."
      }
    ]
  end
end
