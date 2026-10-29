defmodule XpressbusWeb.AdminDashboardLive do
  use XpressbusWeb, :live_view
  import XpressbusWeb.AdminComponents
  alias Xpressbus.{Repo, Tickets, Hotels, HiddenGems, CarHires, Events}
  alias Xpressbus.Bookings.Bus
  import Ecto.Query

  def mount(_params, session, socket) do
    admin_id = session["admin_id"]

    if admin_id do
      page = 1
      page_size = 10
      total_count = Tickets.count_tickets()
      stats = load_stats()

      {:ok,
       socket
       |> assign(:page_title, "Admin Dashboard")
       |> assign(:stats, stats)
       |> assign(:active_tab, "dashboard")
       |> assign(:page, page)
       |> assign(:page_size, page_size)
       |> assign(:total_count, total_count)
       |> assign(:sidebar_collapsed, false)
       |> assign(:bus_expanded, true)
       |> assign(:chyllz_expanded, true)
       |> assign(:settings_expanded, true)
       |> assign(:recent_tickets, Tickets.paginate_tickets(page, page_size))}
    else
      {:ok,
       socket
       |> assign(:page_title, "Admin Dashboard")
       |> Phoenix.LiveView.redirect(to: ~p"/admin/login")}
    end
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    page = String.to_integer(page)
    page_size = socket.assigns.page_size

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:recent_tickets, Tickets.paginate_tickets(page, page_size))}
  end

  def handle_event("toggle_bus", %{"category" => "bus"}, socket) do
    bus_expanded = not socket.assigns.bus_expanded
    {:noreply, assign(socket, :bus_expanded, bus_expanded)}
  end

  def handle_event("toggle_chyllz", %{"category" => "chyllz"}, socket) do
    chyllz_expanded = not socket.assigns.chyllz_expanded
    {:noreply, assign(socket, :chyllz_expanded, chyllz_expanded)}
  end

  def handle_event("toggle_settings", %{"category" => "settings"}, socket) do
    settings_expanded = not socket.assigns.settings_expanded
    {:noreply, assign(socket, :settings_expanded, settings_expanded)}
  end

  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :sidebar_collapsed, not socket.assigns.sidebar_collapsed)}
  end

  defp load_stats do
    buses = Repo.aggregate(Bus, :count, :id)
    tickets = Repo.aggregate(Tickets.Ticket, :count, :id)
    hotels = Hotels.count_hotels()
    gems = HiddenGems.count_hidden_gems()
    cars = CarHires.count_car_hires()
    events = Events.count_events()

    total_revenue =
      Repo.all(from(t in Tickets.Ticket, select: t.price))
      |> Enum.map(&parse_price/1)
      |> Enum.sum()

    %{
      buses: buses,
      tickets: tickets,
      hotels: hotels,
      gems: gems,
      cars: cars,
      events: events,
      revenue: total_revenue,
      revenue_display: format_revenue(total_revenue)
    }
  end

  defp format_revenue(0), do: "Ksh 0"
  defp format_revenue(amount), do: "Ksh #{amount}"

  defp parse_price(nil), do: 0

  defp parse_price(price_string) when is_binary(price_string) do
    # Industrial parsing: handles decimals and formatting safely
    numeric_str = String.replace(price_string, ~r/[^0-9.]/, "")

    case Float.parse(numeric_str) do
      {val, _} -> round(val)
      :error -> 0
    end
  end

  defp parse_price(_), do: 0

  defp format_date(nil), do: ""
  defp format_date(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%b %d, %Y")
  defp format_date(datetime), do: datetime
end
