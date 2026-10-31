defmodule XpressbusWeb.OperatorLive do
  @moduledoc """
  Operator landing pages at `/operators/:slug`.

  Each page lists that operator's real routes, fares, cities and ratings, and
  links into route/city pages (and back), completing the route → city →
  operator internal-link mesh.
  """

  use XpressbusWeb, :live_view

  import XpressbusWeb.BrandComponents

  alias XpressbusWeb.Operators
  alias XpressbusWeb.SEO

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:step, :operator)
     |> assign(:footer_tab, "about")
     |> assign(:current_user, session["user_id"])
     |> assign(:operator, nil)
     |> assign(:operators, Operators.top(20))
     |> assign(:routes, [])
     |> assign(:cities, [])
     |> assign(:page_title, "Bus operators in Kenya")
     |> assign(:page_description, "Compare bus operators, routes and fares on Komiuta.")
     |> assign(:page_robots, "index,follow")
     |> assign(:page_json_ld, nil)}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _url, socket) do
    case Operators.find(slug) do
      nil ->
        {:noreply, push_navigate(socket, to: "/")}

      operator ->
        routes = Operators.routes(operator.name)
        cities = Operators.cities(operator.name)
        url = SEO.base_url() <> "/operators/" <> slug

        {:noreply,
         socket
         |> assign(:operator, operator)
         |> assign(:routes, routes)
         |> assign(:cities, cities)
         |> assign(:page_title, "#{operator.name} Bus Tickets — Routes, Fares & Schedules")
         |> assign(
           :page_description,
           "Book #{operator.name} bus tickets on Komiuta. Compare #{operator.name} routes, departure times and live fares, with M-PESA payment and instant SMS/email tickets."
         )
         |> assign(:page_canonical, url)
         |> assign(:page_json_ld, operator_json_ld(operator, routes, cities, url))}
    end
  end

  def handle_params(_params, _url, socket) do
    operators = Operators.top(20)

    {:noreply,
     socket
     |> assign(:operators, operators)
     |> assign(:page_title, "Bus Operators in Kenya — Routes, Fares & Schedules")
     |> assign(
       :page_description,
       "Compare bus operators on Komiuta: routes, departure times and live fares from Kenya's bus companies. Book seats online with M-PESA, card or mobile money."
     )
     |> assign(:page_canonical, SEO.base_url() <> "/operators")
     |> assign(:page_json_ld, operator_index_json_ld(operators))}
  end

  @impl true
  def handle_event("change_footer_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :footer_tab, tab)}
  end

  defp operator_index_json_ld(operators) do
    [
      SEO.organization(),
      %{
        "@context" => "https://schema.org",
        "@type" => "ItemList",
        "name" => "Bus operators on Komiuta",
        "itemListElement" =>
          operators
          |> Enum.with_index(1)
          |> Enum.map(fn {operator, index} ->
            %{
              "@type" => "ListItem",
              "position" => index,
              "name" => operator.name,
              "url" => SEO.base_url() <> "/operators/" <> Operators.slug(operator.name)
            }
          end)
      },
      SEO.breadcrumb([
        {"Home", SEO.base_url() <> "/"},
        {"Bus operators", SEO.base_url() <> "/operators"}
      ])
    ]
  end

  defp operator_json_ld(operator, routes, cities, url) do
    [
      %{
        "@context" => "https://schema.org",
        "@type" => "Organization",
        "name" => operator.name,
        "url" => url,
        "description" => "#{operator.name} intercity bus operator on Komiuta.",
        "parentOrganization" => %{
          "@type" => "Organization",
          "name" => "Komiuta",
          "url" => SEO.base_url()
        }
      },
      %{
        "@context" => "https://schema.org",
        "@type" => "ItemList",
        "name" => "Routes operated by #{operator.name}",
        "itemListElement" =>
          routes
          |> Enum.with_index(1)
          |> Enum.map(fn {route, index} ->
            %{
              "@type" => "ListItem",
              "position" => index,
              "name" => "#{route.from} to #{route.to} bus",
              "url" => SEO.route_url(route.from, route.to)
            }
          end)
      },
      SEO.breadcrumb([
        {"Home", SEO.base_url() <> "/"},
        {"Bus operators", SEO.base_url() <> "/operators"},
        {operator.name, url}
      ]),
      %{
        "@context" => "https://schema.org",
        "@type" => "ItemList",
        "name" => "Cities served by #{operator.name}",
        "itemListElement" =>
          cities
          |> Enum.with_index(1)
          |> Enum.map(fn {city, index} ->
            city_slug = String.downcase(city)

            %{
              "@type" => "ListItem",
              "position" => index,
              "name" => city,
              "url" => SEO.base_url() <> "/cities/" <> city_slug
            }
          end)
      }
    ]
  end
end
