defmodule XpressbusWeb.TicketLive do
  use XpressbusWeb, :live_view
  alias Xpressbus.Tickets

  def mount(params, _session, socket) do
    ticket_id = Map.get(params, "ticket_id", "")

    socket =
      socket
      |> assign(:page_title, "Track Ticket")
      |> assign(:search_query, ticket_id)
      |> assign(:ticket, nil)
      |> assign(:search_results, [])
      |> assign(:searched, false)
      |> assign(:search_form, to_form(%{"query" => ticket_id}))

    if ticket_id != "" do
      {:ok, perform_search(ticket_id, socket)}
    else
      {:ok, socket}
    end
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, perform_search(query, socket)}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:ticket, nil)
     |> assign(:search_results, [])
     |> assign(:searched, false)
     |> assign(:search_form, to_form(%{"query" => ""}))}
  end

  def handle_event("print_ticket", _params, socket) do
    {:noreply, put_flash(socket, :info, "Ticket download will be available soon.")}
  end

  defp perform_search(query, socket) do
    query = String.trim(query)

    results =
      if query != "" do
        Tickets.search_tickets(query)
      else
        []
      end

    ticket = if query != "", do: Tickets.get_ticket(query), else: nil

    socket
    |> assign(:search_query, query)
    |> assign(:search_results, results)
    |> assign(:ticket, ticket)
    |> assign(:searched, true)
    |> assign(:search_form, to_form(%{"query" => query}))
  end
end
