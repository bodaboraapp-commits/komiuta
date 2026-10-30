defmodule XpressbusWeb.TicketLive do
  use XpressbusWeb, :live_view
  import XpressbusWeb.BrandComponents
  alias Xpressbus.Accounts
  alias Xpressbus.Tickets
  alias XpressbusWeb.Plugs.IpThrottle

  @lookup_limit 15
  @lookup_window_seconds 60

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Track Ticket")
     |> assign(:step, :ticket)
     |> assign(:current_user, session["user_id"])
     |> assign(:signed_in_user, signed_in_user(session["user_id"]))
     |> assign(:client_ip, client_ip(socket))
     |> assign(:footer_tab, "track")
     |> assign(:search_query, "")
     |> assign(:last4, "")
     |> assign(:ticket, nil)
     |> assign(:ticket_qr, nil)
     |> assign(:search_results, [])
     |> assign(:searched, false)
     |> assign(:lookup_error, nil)
     |> assign(:search_form, to_form(%{"query" => "", "last4" => ""}))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # `ticket_id` arrives as a query parameter from the post-payment flow
    # (/tickets?ticket_id=...). Query parameters are delivered to
    # handle_params/3, not mount/3, so the lookup has to happen here.
    query = params["ticket_id"] || params["query"]
    last4 = params["last4"] || ""

    if is_binary(query) and String.trim(query) != "" do
      {:noreply, perform_search(query, last4, socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("search", params, socket) do
    query = params["query"] || (params["search"] && params["search"]["query"]) || ""
    last4 = params["last4"] || (params["search"] && params["search"]["last4"]) || ""

    {:noreply, perform_search(query, last4, socket)}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:last4, "")
     |> assign(:ticket, nil)
     |> assign(:ticket_qr, nil)
     |> assign(:search_results, [])
     |> assign(:searched, false)
     |> assign(:lookup_error, nil)
     |> assign(:search_form, to_form(%{"query" => "", "last4" => ""}))}
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

  defp perform_search(query, last4, socket) do
    query = String.trim(to_string(query))
    last4 = last4 |> to_string() |> digits_only() |> String.slice(-4, 4)

    case throttle_lookup(socket) do
      {:blocked, retry_after} ->
        socket
        |> assign(:search_query, query)
        |> assign(:last4, last4)
        |> assign(:search_results, [])
        |> assign(:ticket, nil)
        |> assign(:ticket_qr, nil)
        |> assign(:searched, true)
        |> assign(
          :lookup_error,
          "Too many ticket lookups. Please wait #{retry_after} seconds and try again."
        )
        |> assign(:search_form, to_form(%{"query" => query, "last4" => last4}))

      :ok ->
        ticket = if query != "", do: Tickets.get_ticket(query), else: nil
        owner? = owner?(ticket, socket.assigns.signed_in_user)
        authorized? = owner? or last4_matches?(ticket, last4)

        results =
          if query != "" do
            Tickets.search_tickets(query)
            |> Enum.filter(fn result ->
              owner? or last4_matches?(result, last4)
            end)
          else
            []
          end

        socket
        |> assign(:search_query, query)
        |> assign(:last4, last4)
        |> assign(:search_results, results)
        |> assign(:ticket, if(authorized?, do: ticket, else: nil))
        |> assign(:ticket_qr, build_qr(if(authorized?, do: ticket, else: nil)))
        |> assign(:searched, true)
        |> assign(:lookup_error, nil)
        |> assign(:search_form, to_form(%{"query" => query, "last4" => last4}))
    end
  end

  defp throttle_lookup(%{assigns: %{client_ip: nil}}), do: :ok

  defp throttle_lookup(%{assigns: %{client_ip: ip}}) do
    case IpThrottle.allow?(:ticket_lookup, ip, @lookup_limit, @lookup_window_seconds) do
      {:ok, _count} -> :ok
      {:error, retry_after} -> {:blocked, retry_after}
    end
  end

  defp owner?(_ticket, nil), do: false
  defp owner?(nil, _user), do: false

  defp owner?(ticket, %{} = user) do
    user_phone = phone_digits(user.phone)
    ticket_phone = phone_digits(ticket.passenger_phone)

    user_phone != "" and ticket_phone != "" and user_phone == ticket_phone
  end

  defp last4_matches?(nil, _last4), do: false
  defp last4_matches?(_ticket, last4) when last4 in ["", nil], do: false

  defp last4_matches?(ticket, last4) do
    phone = phone_digits(ticket.passenger_phone)
    phone != "" and String.ends_with?(phone, last4)
  end

  defp signed_in_user(nil), do: nil
  defp signed_in_user(user_id), do: Accounts.get_user(user_id)

  defp phone_digits(nil), do: ""
  defp phone_digits(phone), do: phone |> to_string() |> digits_only()
  defp digits_only(value), do: String.replace(to_string(value), ~r/[^0-9]/, "")

  defp client_ip(socket) do
    if connected?(socket) do
      case get_connect_info(socket, :peer_data) do
        %{address: address} -> to_string(:inet.ntoa(address))
        _ -> nil
      end
    else
      nil
    end
  rescue
    _ -> nil
  end

  # The QR code is generated locally (no third-party image service) and encodes
  # the public ticket-tracking URL, so a scanner opens the ticket directly.
  defp build_qr(nil), do: nil

  defp build_qr(ticket) do
    last4 = ticket.passenger_phone |> phone_digits() |> String.slice(-4, 4)

    payload =
      XpressbusWeb.Endpoint.url() <>
        "/tickets?ticket_id=" <>
        URI.encode_www_form(ticket.ticket_id) <> "&last4=" <> last4

    XpressbusWeb.QRCode.svg(payload, aria_label: "Boarding QR code")
  end
end
