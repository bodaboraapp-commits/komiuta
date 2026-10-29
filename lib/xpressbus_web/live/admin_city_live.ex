defmodule XpressbusWeb.AdminCityLive do
  use XpressbusWeb, :live_view
  import XpressbusWeb.AdminComponents
  alias Xpressbus.Cities

  def mount(_params, session, socket) do
    admin_id = session["admin_id"]

    if admin_id do
      page = 1
      page_size = 10
      total_count = Cities.count_cities()

      {:ok,
       socket
       |> assign(:page_title, "Cities")
       |> assign(:active_tab, "city")
       |> assign(:page, page)
       |> assign(:page_size, page_size)
       |> assign(:total_count, total_count)
       |> assign(:sidebar_collapsed, false)
       |> assign(:bus_expanded, true)
       |> assign(:chyllz_expanded, true)
       |> assign(:settings_expanded, true)
       |> assign(:cities, Cities.paginate_cities(page, page_size))
       |> assign(:form, to_form(%{"name" => "", "region" => ""}))}
    else
      {:ok,
       socket
       |> assign(:page_title, "Cities")
       |> Phoenix.LiveView.redirect(to: ~p"/admin/login")}
    end
  end

  def handle_event("save", %{"name" => name, "region" => region}, socket) do
    case Cities.create_city(%{name: name, region: region}) do
      {:ok, _city} ->
        page = socket.assigns.page
        page_size = socket.assigns.page_size
        total_count = Cities.count_cities()

        {:noreply,
         socket
         |> put_flash(:info, "City added successfully")
         |> assign(:total_count, total_count)
         |> assign(:cities, Cities.paginate_cities(page, page_size))
         |> assign(:form, to_form(%{"name" => "", "region" => ""}))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Error adding city")}
    end
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    page = String.to_integer(page)
    page_size = socket.assigns.page_size

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:cities, Cities.paginate_cities(page, page_size))}
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
end
