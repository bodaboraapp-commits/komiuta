defmodule XpressbusWeb.TicketLive do
  use XpressbusWeb, :live_view
  import XpressbusWeb.BrandComponents
  alias Xpressbus.Tickets

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Track Ticket")
     |> assign(:step, :ticket)
     |> assign(:current_user, session["user_id"])
     |> assign(:footer_tab, "track")
     |> assign(:search_query, "")
     |> assign(:ticket, nil)
     |> assign(:ticket_qr, nil)
     |> assign(:search_results, [])
     |> assign(:searched, false)
     |> assign(:search_form, to_form(%{"query" => ""}))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # `ticket_id` arrives as a query parameter from the post-payment flow
    # (/tickets?ticket_id=...). Query parameters are delivered to
    # handle_params/3, not mount/3, so the lookup has to happen here.
    query = params["ticket_id"] || params["query"]

    if is_binary(query) and String.trim(query) != "" do
      {:noreply, perform_search(query, socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, perform_search(query, socket)}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:ticket, nil)
     |> assign(:ticket_qr, nil)
     |> assign(:search_results, [])
     |> assign(:searched, false)
     |> assign(:search_form, to_form(%{"query" => ""}))}
  end

  def handle_event("ticket_shared", _params, socket) do
    {:noreply, put_flash(socket, :info, "Ticket link ready to share.")}
  end

  def handle_event("change_footer_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :footer_tab, tab)}
  end

  def handle_event("back_to_search", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  defp perform_search(query, socket) do
    query = String.trim(query)
    results = if query != "", do: Tickets.search_tickets(query), else: []
    ticket = if query != "", do: Tickets.get_ticket(query), else: nil

    socket
    |> assign(:search_query, query)
    |> assign(:search_results, results)
    |> assign(:ticket, ticket)
    |> assign(:ticket_qr, build_qr(ticket))
    |> assign(:searched, true)
    |> assign(:search_form, to_form(%{"query" => query}))
  end

  # The QR code is generated locally (no third-party image service) and encodes
  # the public ticket-tracking URL, so a scanner opens the ticket directly.
  defp build_qr(nil), do: nil

  defp build_qr(ticket) do
    payload =
      XpressbusWeb.Endpoint.url() <>
        "/tickets?ticket_id=" <> URI.encode_www_form(ticket.ticket_id)

    XpressbusWeb.QRCode.svg(payload, aria_label: "Boarding QR code")
  end
end
