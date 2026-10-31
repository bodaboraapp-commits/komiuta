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
      "name" => "Komiuta",
      "url" => @base_url,
      "logo" => @base_url <> "/images/logo_brand.png",
      "description" =>
        "Komiuta is an East African bus booking platform for intercity bus tickets across Kenya, Uganda and Tanzania, with M-PESA, card and mobile money payments.",
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
      "name" => "Komiuta",
      "url" => @base_url,
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
      "busName" => operator || "Komiuta partner bus",
      "provider" => %{"@type" => "Organization", "name" => "Komiuta", "url" => @base_url},
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
          "Fares start from about KES #{price_from}. Normal seats are usually the cheapest option, while VIP and first-class seats cost more. Prices update daily on Komiuta."
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
end
