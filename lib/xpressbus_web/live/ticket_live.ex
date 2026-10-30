defmodule XpressbusWeb.TicketLive do
  use XpressbusWeb, :live_view
  import XpressbusWeb.BrandComponents
  alias Xpressbus.Accounts
  alias Xpressbus.TicketAccess
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
     |> assign(:phone, "")
     |> assign(:ticket, nil)
     |> assign(:ticket_qr, nil)
     |> assign(:share_url, nil)
     |> assign(:search_results, [])
     |> assign(:searched, false)
     |> assign(:lookup_error, nil)
     |> assign(:search_form, to_form(%{"query" => "", "phone" => ""}))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # `ticket_id` arrives as a query parameter from the post-payment flow
    # (/tickets?ticket_id=...&token=...). Query parameters are delivered to
    # handle_params/3, not mount/3, so the lookup has to happen here.
    query = params["ticket_id"] || params["query"]
    phone = params["phone"] || ""
    access_token = params["token"]

    if is_binary(query) and String.trim(query) != "" do
      {:noreply, perform_search(query, phone, access_token, socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("search", params, socket) do
    query = params["query"] || (params["search"] && params["search"]["query"]) || ""
    phone = params["phone"] || (params["search"] && params["search"]["phone"]) || ""

    {:noreply, perform_search(query, phone, nil, socket)}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:phone, "")
     |> assign(:ticket, nil)
     |> assign(:ticket_qr, nil)
     |> assign(:share_url, nil)
     |> assign(:search_results, [])
     |> assign(:searched, false)
     |> assign(:lookup_error, nil)
     |> assign(:search_form, to_form(%{"query" => "", "phone" => ""}))}
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

  defp perform_search(query, phone, access_token, socket) do
    query = String.trim(to_string(query))
    phone = phone |> to_string() |> String.trim()
    normalized_phone = TicketAccess.normalize(phone)

    case throttle_lookup(socket) do
      {:blocked, retry_after} ->
        socket
        |> assign(:search_query, query)
        |> assign(:phone, phone)
        |> assign(:search_results, [])
        |> assign(:ticket, nil)
        |> assign(:ticket_qr, nil)
        |> assign(:share_url, nil)
        |> assign(:searched, true)
        |> assign(
          :lookup_error,
          "Too many ticket lookups. Please wait #{retry_after} seconds and try again."
        )
        |> assign(:search_form, to_form(%{"query" => query, "phone" => phone}))

      :ok ->
        ticket = if query != "", do: Tickets.get_ticket(query), else: nil
        owner? = owner?(ticket, socket.assigns.signed_in_user)
        token_ok? = TicketAccess.valid?(ticket, access_token)

        phone_ok? =
          normalized_phone != "" and
            TicketAccess.normalize(ticket && ticket.passenger_phone) == normalized_phone

        authorized? = token_ok? or owner? or phone_ok?

        results =
          if query != "" do
            Tickets.search_tickets(query)
            |> Enum.filter(fn result ->
              owner? or
                (normalized_phone != "" and
                   TicketAccess.normalize(result.passenger_phone) == normalized_phone)
            end)
          else
            []
          end

        ticket = if authorized?, do: ticket, else: nil

        socket
        |> assign(:search_query, query)
        |> assign(:phone, phone)
        |> assign(:search_results, results)
        |> assign(:ticket, ticket)
        |> assign(:ticket_qr, build_qr(ticket))
        |> assign(:share_url, if(ticket, do: TicketAccess.path(ticket), else: nil))
        |> assign(:searched, true)
        |> assign(:lookup_error, nil)
        |> assign(:search_form, to_form(%{"query" => query, "phone" => phone}))
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
    user_phone = TicketAccess.normalize(user.phone)
    ticket_phone = TicketAccess.normalize(ticket.passenger_phone)

    user_phone != "" and ticket_phone != "" and user_phone == ticket_phone
  end

  defp signed_in_user(nil), do: nil
  defp signed_in_user(user_id), do: Accounts.get_user(user_id)

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
  # a signed ticket link (no phone number in the URL).
  defp build_qr(nil), do: nil

  defp build_qr(ticket) do
    XpressbusWeb.QRCode.svg(TicketAccess.url(ticket), aria_label: "Boarding QR code")
  end
end
