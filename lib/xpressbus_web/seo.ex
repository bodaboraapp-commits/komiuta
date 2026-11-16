defmodule XpressbusWeb.SEO do
  @moduledoc """
  Shared SEO / AI-search helpers: canonical URLs, JSON-LD builders and FAQ
  content for the programmatic route pages.
  """

  @base_url "https://www.komiuta.com"

  def base_url, do: @base_url

  @doc "Encodes a route pair the same way the router expects it."
  def route_path(from, to) do
    "/buses/" <> URI.encode("#{from}-to-#{to}", &URI.char_unreserved?/1)
  end

  def route_url(from, to), do: @base_url <> route_path(from, to)

  def organization do
    %{
      "@context" => "https://schema.org",
      "@type" => "Organization",
      "name" => "KOMIUTA",
      "alternateName" => "KOMIUTA Bus Booking",
      "url" => @base_url,
      "logo" => @base_url <> "/images/logo_brand.png",
      "description" =>
        "KOMIUTA Bus Booking is a transport technology and booking platform designed for public transit, intercity travel, and matatu/bus fleet management. Book intercity bus tickets across Kenya, Uganda and Tanzania with M-PESA, card or mobile money.",
      "sameAs" => [
        "https://github.com/bodaboraapp-commits/komiuta"
      ],
      "contactPoint" => [
        %{
          "@type" => "ContactPoint",
          "telephone" => "+254800211211",
          "contactType" => "customer support",
          "areaServed" => "KE",
          "availableLanguage" => ["English", "Swahili"]
        }
      ]
    }
  end

  def website do
    %{
      "@context" => "https://schema.org",
      "@type" => "WebSite",
      "name" => "KOMIUTA",
      "alternateName" => "KOMIUTA Bus Booking",
      "url" => @base_url,
      "description" =>
        "KOMIUTA Bus Booking is a transport technology and booking platform designed for public transit, intercity travel, and matatu/bus fleet management.",
      "potentialAction" => %{
        "@type" => "SearchAction",
        "target" => @base_url <> "/?q={search_term_string}",
        "query-input" => "required name=search_term_string"
      }
    }
  end

  def breadcrumb(items) do
    %{
      "@context" => "https://schema.org",
      "@type" => "BreadcrumbList",
      "itemListElement" =>
        items
        |> Enum.with_index(1)
        |> Enum.map(fn {{name, url}, index} ->
          %{"@type" => "ListItem", "position" => index, "name" => name, "item" => url}
        end)
    }
  end

  def faq_page(faqs) when is_list(faqs) do
    %{
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "mainEntity" =>
        Enum.map(faqs, fn %{question: question, answer: answer} ->
          %{
            "@type" => "Question",
            "name" => question,
            "acceptedAnswer" => %{"@type" => "Answer", "text" => answer}
          }
        end)
    }
  end

  def bus_trip(from, to, price, operator) do
    %{
      "@context" => "https://schema.org",
      "@type" => "BusTrip",
      "name" => "#{from} to #{to} bus",
      "busName" => operator || "KOMIUTA partner bus",
      "provider" => %{"@type" => "Organization", "name" => "KOMIUTA", "url" => @base_url},
      "departureBusStop" => %{"@type" => "BusStop", "name" => "#{from} CBD terminals"},
      "arrivalBusStop" => %{"@type" => "BusStop", "name" => "#{to} bus terminal"},
      "offers" => %{
        "@type" => "Offer",
        "price" => price,
        "priceCurrency" => "KES",
        "availability" => "https://schema.org/InStock",
        "url" => route_url(from, to)
      }
    }
  end

  @doc "Route FAQ content used for the visible FAQ and FAQPage schema."
  def route_faqs(from, to, price_from) do
    [
      %{
        question: "How much is a bus ticket from #{from} to #{to}?",
        answer:
          "Fares start from about KES #{price_from}. Normal seats are usually the cheapest option, while VIP and first-class seats cost more. Prices update daily on KOMIUTA."
      },
      %{
        question: "How long does the bus take from #{from} to #{to}?",
        answer:
          "Direct buses typically take between 6 and 9 hours depending on the operator, departure time and traffic. The fastest options are shown first when you sort by fastest."
      },
      %{
        question: "Can I pay for my #{from} to #{to} bus ticket with M-PESA?",
        answer:
          "Yes. Choose M-PESA at checkout, enter the phone number you want to pay from, and approve the STK push. You receive your ticket by SMS and email immediately after payment."
      },
      %{
        question: "Where do buses from #{from} to #{to} depart and arrive?",
        answer:
          "Departure and arrival terminals are shown on each bus card before you select a seat. Most services use CBD terminals at the departure city and the main bus park at the destination."
      },
      %{
        question: "Can I change or cancel my #{from} to #{to} bus ticket?",
        answer:
          "Changes and cancellations depend on the operator's fare rules. Free cancellation is available up to 2 hours before departure on eligible tickets, shown at checkout."
      }
    ]
  end

  # ---------------------------------------------------------------------------
  # Public listing pages (hotels, hidden gems, car hire, events)
  # ---------------------------------------------------------------------------

  @listing_bases %{
    "hotel" => "/tour-packages/hotels",
    "hidden_gem" => "/our-packages/hidden-gems",
    "car_hire" => "/tour-packages/car",
    "event" => "/tour-packages/events"
  }

  @listing_labels %{
    "hotel" => "Hotels",
    "hidden_gem" => "Hidden Gems",
    "car_hire" => "Car Hire",
    "event" => "Events"
  }

  def listing_base_path(kind), do: Map.fetch!(@listing_bases, kind)
  def listing_index_path(kind), do: listing_base_path(kind)
  def listing_label(kind), do: Map.fetch!(@listing_labels, kind)

  def slugify(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
    |> String.slice(0, 90)
  end

  def slugify(_value), do: ""

  def listing_name("hotel", item), do: item.name
  def listing_name("hidden_gem", item), do: item.title
  def listing_name("car_hire", item), do: item.car_name
  def listing_name("event", item), do: item.title

  def listing_slug(kind, item) do
    raw =
      case kind do
        "event" -> "#{listing_name(kind, item)}-#{item.date}"
        "car_hire" -> "#{listing_name(kind, item)}-#{item.location}"
        _ -> listing_name(kind, item)
      end

    slugify(raw)
  end

  def listing_path(kind, item), do: listing_base_path(kind) <> "/" <> listing_slug(kind, item)
  def listing_url(kind, item), do: @base_url <> listing_path(kind, item)

  def absolute_url(path) when is_binary(path) do
    cond do
      String.starts_with?(path, "http://") or String.starts_with?(path, "https://") -> path
      String.starts_with?(path, "/") -> @base_url <> path
      true -> @base_url <> "/" <> path
    end
  end

  def absolute_url(_path), do: nil

  def listing_image(kind, item)

  def listing_image("hotel", item) do
    case List.first(Map.get(item, :images) || []) do
      nil -> "/images/room_1.webp"
      image -> image
    end
  end

  def listing_image(_kind, item) do
    case List.first(Map.get(item, :images) || []) do
      nil -> "/images/hero_bg-1024.avif"
      image -> image
    end
  end

  def listing_details("hotel", item) do
    compact([
      {"Location", item.location},
      {"Price", item.price_per_night && "KES #{price_string(item.price_per_night)} / night"},
      {"Amenities", amenities(item.amenities)}
    ])
  end

  def listing_details("hidden_gem", item) do
    compact([
      {"Location", item.location},
      {"Category", item.category},
      {"Region", item.region},
      {"Best time", item.best_time},
      {"Entry fee", item.entry_fee},
      {"Access", item.access_notes}
    ])
  end

  def listing_details("car_hire", item) do
    compact([
      {"Vehicle", item.type},
      {"Location", item.location},
      {"Price", item.price_per_day && "KES #{price_string(item.price_per_day)} / day"}
    ])
  end

  def listing_details("event", item) do
    compact([
      {"Date", item.date && Calendar.strftime(item.date, "%d %b %Y")},
      {"Location", item.location}
    ])
  end

  def listing_maps_url("hotel", _item), do: nil
  def listing_maps_url(_kind, item), do: Map.get(item, :google_maps_url)
  def listing_website_url(_kind, item), do: Map.get(item, :website_url)

  def item_list(kind, items) do
    %{
      "@context" => "https://schema.org",
      "@type" => "ItemList",
      "name" => "Chyllz #{listing_label(kind)}",
      "numberOfItems" => length(items),
      "itemListElement" =>
        items
        |> Enum.with_index(1)
        |> Enum.map(fn {item, position} ->
          image = listing_image(kind, item) |> absolute_url()

          %{
            "@type" => "ListItem",
            "position" => position,
            "name" => listing_name(kind, item),
            "url" => listing_url(kind, item)
          }
          |> put_if("image", image)
        end)
    }
  end

  def listing_schema(kind, item, url, image) do
    base = %{
      "@context" => "https://schema.org",
      "url" => url,
      "name" => listing_name(kind, item),
      "description" => Map.get(item, :description),
      "image" => image
    }

    base
    |> put_if("address", listing_address(kind, item))
    |> put_if("geo", listing_geo(kind, item))
    |> put_if("aggregateRating", listing_rating(kind, item))
    |> put_if("priceRange", listing_price_range(kind, item))
    |> Map.merge(listing_type_fields(kind, item, url))
  end

  defp listing_type_fields("hotel", _item, _url), do: %{"@type" => "Hotel"}
  defp listing_type_fields("hidden_gem", _item, _url), do: %{"@type" => "TouristAttraction"}

  defp listing_type_fields("car_hire", item, url) do
    %{
      "@type" => "Product",
      "offers" => %{
        "@type" => "Offer",
        "price" => item.price_per_day && Decimal.to_string(item.price_per_day),
        "priceCurrency" => "KES",
        "availability" => "https://schema.org/InStock",
        "url" => url
      }
    }
  end

  defp listing_type_fields("event", item, _url) do
    %{
      "@type" => "Event",
      "startDate" => item.date && Date.to_iso8601(item.date),
      "eventStatus" => "https://schema.org/EventScheduled",
      "eventAttendanceMode" => "https://schema.org/OfflineEventAttendanceMode",
      "location" => %{
        "@type" => "Place",
        "name" => item.location,
        "address" => %{
          "@type" => "PostalAddress",
          "addressLocality" => item.location,
          "addressCountry" => "KE"
        }
      }
    }
  end

  defp listing_address(kind, item) when kind in ["hotel", "hidden_gem"] do
    %{
      "@type" => "PostalAddress",
      "addressLocality" => Map.get(item, :location) || Map.get(item, :region),
      "addressRegion" => Map.get(item, :region),
      "addressCountry" => "KE"
    }
  end

  defp listing_address(_kind, _item), do: nil

  defp listing_geo(_kind, item) do
    if Map.get(item, :latitude) && Map.get(item, :longitude) do
      %{
        "@type" => "GeoCoordinates",
        "latitude" => item.latitude,
        "longitude" => item.longitude
      }
    end
  end

  defp listing_rating(kind, item) when kind in ["hotel", "hidden_gem"] do
    if Map.get(item, :rating) do
      %{
        "@type" => "AggregateRating",
        "ratingValue" => item.rating |> Decimal.new() |> Decimal.to_float() |> Float.round(1),
        "reviewCount" => Map.get(item, :review_count) || 0,
        "bestRating" => 5
      }
    end
  end

  defp listing_rating(_kind, _item), do: nil

  defp listing_price_range("hotel", item) do
    item.price_per_night && "KES #{price_string(item.price_per_night)}"
  end

  defp listing_price_range(_kind, _item), do: nil

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, value), do: Map.put(map, key, value)

  defp compact(pairs) do
    Enum.reject(pairs, fn {_label, value} -> is_nil(value) or value == "" end)
  end

  defp amenities(nil), do: nil
  defp amenities([]), do: nil
  defp amenities(list), do: Enum.take(list, 4) |> Enum.join(" · ")

  defp price_string(%Decimal{} = value),
    do: value |> Decimal.round(0) |> Decimal.to_string(:normal)

  defp price_string(value) when is_integer(value), do: Integer.to_string(value)
  defp price_string(value) when is_float(value), do: value |> round() |> Integer.to_string()
  defp price_string(value), do: value
end
