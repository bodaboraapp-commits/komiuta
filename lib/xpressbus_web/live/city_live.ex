defmodule XpressbusWeb.CityLive do
  @moduledoc """
  Programmatic city landing pages: `/cities/:slug`.

  These are server-rendered, internal-link rich, schema-marked pages targeting
  queries such as "buses from Nairobi" and "Nairobi bus fares".
  """

  use XpressbusWeb, :live_view

  import Ecto.Query
  import XpressbusWeb.BrandComponents

  alias Xpressbus.Bookings.Bus
  alias Xpressbus.Repo
  alias XpressbusWeb.Cities
  alias XpressbusWeb.SEO

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:step, :city)
     |> assign(:footer_tab, "about")
     |> assign(:current_user, session["user_id"])
     |> assign(:city, nil)
     |> assign(:routes, [])
     |> assign(:faqs, [])
     |> assign(:page_title, "Bus tickets in Kenya")
     |> assign(
       :page_description,
       "Find and book intercity bus tickets across Kenya with Komiuta."
     )
     |> assign(:page_canonical, SEO.base_url() <> "/cities")
     |> assign(:page_robots, "index,follow")
     |> assign(:page_json_ld, nil)}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _url, socket) do
    case Cities.get(slug) do
      nil ->
        {:noreply, push_navigate(socket, to: "/")}

      city ->
        routes = routes_from_city(city.name)
        faqs = city_faqs(city.name)

        {:noreply,
         socket
         |> assign(:city, city)
         |> assign(:routes, routes)
         |> assign(:faqs, faqs)
         |> assign(:page_title, "Buses from #{city.name} — Bus Tickets, Fares & Booking")
         |> assign(
           :page_description,
           "Book bus tickets from #{city.name}, Kenya. Compare live fares, operators and departure times from #{city.name} with M-PESA payment and instant SMS tickets."
         )
         |> assign(:page_canonical, SEO.base_url() <> "/cities/" <> slug)
         |> assign(:page_json_ld, city_json_ld(city, routes, faqs))}
    end
  end

  @impl true
  def handle_event("change_footer_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :footer_tab, tab)}
  end

  defp routes_from_city(city_name) do
    Repo.all(
      from(b in Bus,
        where: fragment("LOWER(?) = LOWER(?)", b.from, ^city_name),
        order_by: [asc: b.travel_date],
        limit: 800
      )
    )
    |> Enum.group_by(& &1.to)
    |> Enum.map(fn {to, buses} ->
      prices =
        buses
        |> Enum.map(&parse_price(&1.price))
        |> Enum.reject(&is_nil/1)

      %{
        to: to,
        count: length(buses),
        min_price: Enum.min(prices, fn -> nil end),
        operators:
          buses
          |> Enum.map(& &1.company)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()
          |> Enum.take(3)
      }
    end)
    |> Enum.sort_by(&(-&1.count))
    |> Enum.take(12)
  end

  defp parse_price(value) when is_binary(value) do
    digits = String.replace(value, ~r/[^0-9]/, "")

    case Integer.parse(digits) do
      {price, _} when price > 0 -> price
      _ -> nil
    end
  end

  defp parse_price(_), do: nil

  defp city_faqs(city) do
    [
      %{
        question: "How much is a bus ticket from #{city}?",
        answer:
          "Fares from #{city} depend on the destination, operator and seat class. Komiuta shows the live fare for every bus before you book, with M-PESA, card and mobile money options."
      },
      %{
        question: "Where do buses from #{city} depart?",
        answer:
          "Departure terminals are shown on each bus before checkout. Operators usually use the main bus parks and stages in #{city}, and the exact boarding point is included on your ticket."
      },
      %{
        question: "Can I book a bus from #{city} online?",
        answer:
          "Yes. Search your route and date, choose a bus and seat, then pay online. Your ticket is sent instantly by SMS and email and can be viewed with Track Ticket."
      },
      %{
        question: "Do buses from #{city} run every day?",
        answer:
          "Most major routes from #{city} run daily with multiple departures, especially to Nairobi, Mombasa, Kisumu, Eldoret and Nakuru. Live schedules are shown when you search."
      }
    ]
  end

  defp city_json_ld(city, routes, faqs) do
    item_list = %{
      "@context" => "https://schema.org",
      "@type" => "ItemList",
      "name" => "Bus routes from #{city.name}",
      "itemListElement" =>
        routes
        |> Enum.with_index(1)
        |> Enum.map(fn {route, index} ->
          %{
            "@type" => "ListItem",
            "position" => index,
            "name" => "#{city.name} to #{route.to} bus tickets",
            "url" => SEO.route_url(city.name, route.to)
          }
        end)
    }

    [
      SEO.breadcrumb([
        {"Home", SEO.base_url() <> "/"},
        {"Bus tickets", SEO.base_url() <> "/"},
        {"Buses from #{city.name}", SEO.base_url() <> "/cities/" <> String.downcase(city.name)}
      ]),
      item_list,
      SEO.faq_page(faqs)
    ]
  end
end
