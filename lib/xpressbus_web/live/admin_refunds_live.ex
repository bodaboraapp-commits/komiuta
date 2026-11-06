defmodule XpressbusWeb.AdminRefundsLive do
  use XpressbusWeb, :live_view
  import XpressbusWeb.AdminComponents

  alias Xpressbus.Tickets

  @page_size 15

  def mount(_params, session, socket) do
    if session["admin_id"] do
      socket =
        socket
        |> assign(:page_title, "Refunds")
        |> assign(:active_tab, "refunds")
        |> assign(:page_size, @page_size)
        |> assign(:search, "")
        |> assign(:sidebar_collapsed, false)
        |> assign(:bus_expanded, true)
        |> assign(:chyllz_expanded, false)
        |> assign(:settings_expanded, true)
        |> assign(:refund_totals, Tickets.refund_totals())
        |> load_refunds(1, "")

      {:ok, socket}
    else
      {:ok, Phoenix.LiveView.redirect(to: ~p"/admin/login")}
    end
  end

  def handle_event("search", %{"search" => search}, socket) do
    search = to_string(search || "")
    {:noreply, socket |> assign(:search, search) |> load_refunds(1, search)}
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    page = page |> to_string() |> String.to_integer() |> max(1)
    {:noreply, load_refunds(socket, page, socket.assigns.search)}
  end

  def handle_event("toggle_bus", _params, socket) do
    {:noreply, assign(socket, :bus_expanded, !socket.assigns.bus_expanded)}
  end

  def handle_event("toggle_chyllz", _params, socket) do
    {:noreply, assign(socket, :chyllz_expanded, !socket.assigns.chyllz_expanded)}
  end

  def handle_event("toggle_settings", _params, socket) do
    {:noreply, assign(socket, :settings_expanded, !socket.assigns.settings_expanded)}
  end

  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_collapsed, !socket.assigns.sidebar_collapsed)}
  end

  defp load_refunds(socket, page, search) do
    {refunds, total} = Tickets.paginate_refunds(page, socket.assigns.page_size, search)

    socket
    |> assign(:refunds, refunds)
    |> assign(:total_count, total)
    |> assign(:page, page)
    |> assign(:total_pages, max(1, ceil(total / socket.assigns.page_size)))
  end
end
