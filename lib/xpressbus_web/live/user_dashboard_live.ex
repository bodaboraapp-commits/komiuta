defmodule XpressbusWeb.UserDashboardLive do
  use XpressbusWeb, :live_view
  import XpressbusWeb.BrandComponents
  import XpressbusWeb.ChyllzAccountComponents
  alias Xpressbus.{Accounts, ChyllzAccount, Repo, Tickets, Weather}
  alias Xpressbus.Payments.Payment
  alias Xpressbus.Tickets.Ticket
  alias XpressbusWeb.TicketCodes
  import Ecto.Query

  @tabs ~w(bus chyllz wallet transactions referral profile)

  def mount(params, session, socket) do
    user_id_or_phone = session["user_id"]

    if user_id_or_phone do
      # Robust User Resolution: Handles both UUID (Google) and Phone (Legacy)
      user =
        cond do
          # Check if it's a valid UUID (Google users use UUID as session key)
          String.match?(
            user_id_or_phone,
            ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
          ) ->
            Accounts.get_user(user_id_or_phone)

          true ->
            # Legacy/Standard users use Phone as session key
            Accounts.get_user_by_phone(user_id_or_phone)
        end

      if user do
        if Accounts.profile_complete?(user) do
          tickets = list_user_tickets(user)
          transactions = Accounts.list_user_transactions(user.id)
          active_tab = normalize_tab(Map.get(params, "tab"))

          socket =
            socket
            |> assign(:page_title, "My Dashboard")
            |> assign(:page_robots, "noindex,nofollow")
            |> assign(:active_tab, active_tab)
            |> assign(:user, user)
            |> assign(:current_user, user.phone)
            |> assign(:tickets, tickets)
            |> assign(:transactions, transactions)
            |> assign(:selected_ticket, nil)
            |> assign(:show_ticket_modal, false)
            |> assign(:ticket_qr, nil)
            |> assign(:ticket_barcode, nil)
            |> assign(:download_url, nil)
            |> assign(:show_phone_modal, false)
            |> assign(:phone_error, nil)
            |> assign(:profile_form, Accounts.change_user(user) |> to_form())
            |> assign(:show_email_change_modal, false)
            |> assign(:email_change_step, :email)
            |> assign(:email_change_form, to_form(%{"new_email" => ""}))
            |> assign(:email_change_error, nil)
            |> assign(:pending_new_email, nil)
            |> assign(:footer_tab, "about")

          {:ok, socket}
        else
          # Every account must have both a phone number and an email before the
          # dashboard (and its personal data) is shown.
          {:ok,
           socket
           |> Phoenix.LiveView.redirect(to: ~p"/user/complete-profile")}
        end
      else
        {:ok, redirect(socket, to: ~p"/user/login")}
      end
    else
      {:ok,
       socket
       |> assign(:page_title, "My Dashboard")
       |> Phoenix.LiveView.redirect(to: ~p"/user/login")}
    end
  end

  # The active tab lives in the URL (`/dashboard?tab=chyllz`) so a refresh or a
  # shared link opens the same account view.
  def handle_params(params, _uri, socket) do
    socket = assign(socket, :active_tab, normalize_tab(Map.get(params, "tab")))

    socket =
      case Map.get(socket.assigns, :user) do
        nil -> socket
        user -> maybe_load_chyllz_account(socket, user)
      end

    {:noreply, socket}
  end

  def handle_info({:load_weather, query}, socket) do
    {:noreply, fetch_weather(socket, query)}
  end

  # LiveView only keeps the messages a LiveView declares; the dashboard also
  # receives internal notifications it does not need to act on (for example the
  # Swoosh test adapter telling the delivering process about an email).
  def handle_info(_message, socket), do: {:noreply, socket}

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, push_patch(socket, to: tab_path(normalize_tab(tab)))}
  end

  # Weather search on the My Chyllz tab. The first forecast arrives
  # asynchronously (see `load_weather/3`); a search is user-initiated and
  # therefore loaded straight away.
  def handle_event("search_weather", %{"city" => city}, socket) do
    query = normalize_city(city)

    if query == "" do
      {:noreply, put_flash(socket, :error, "Type a city name to see its weather.")}
    else
      {:noreply, socket |> assign(:weather_query, query) |> load_weather(query)}
    end
  end

  def handle_event("refresh_weather", _params, socket) do
    {:noreply, load_weather(socket, socket.assigns.weather_query)}
  end

  def handle_event("view_ticket", %{"ticket_id" => ticket_id}, socket) do
    user = socket.assigns.user

    ticket =
      case Tickets.get_ticket(ticket_id) do
        nil -> nil
        ticket -> if ticket_belongs_to_user?(ticket, user), do: ticket, else: nil
      end

    if ticket do
      # The boarding codes are the same locally generated codes used on the
      # public ticket page: a QR for the signed ticket URL and a Code 128B
      # barcode for the ticket number. They are only rendered while this
      # ticket's modal is open.
      {:noreply,
       socket
       |> assign(:selected_ticket, ticket)
       |> assign(:show_ticket_modal, true)
       |> assign(:ticket_qr, TicketCodes.qr(ticket))
       |> assign(:ticket_barcode, TicketCodes.barcode(ticket, responsive: true, height: 56))
       |> assign(:download_url, TicketCodes.download_url(ticket))}
    else
      {:noreply, put_flash(socket, :error, "Ticket not found on your account.")}
    end
  end

  def handle_event("close_ticket", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_ticket, nil)
     |> assign(:show_ticket_modal, false)
     |> assign(:ticket_qr, nil)
     |> assign(:ticket_barcode, nil)
     |> assign(:download_url, nil)}
  end

  def handle_event("share_trip", %{"url" => url, "title" => title}, socket) do
    # The share sheet itself runs in the browser; the server only sanitises the
    # values and pushes them back through a `phx:share_trip` window event.
    url = url |> to_string() |> String.slice(0, 500)
    title = title |> to_string() |> String.slice(0, 120)

    {:noreply, push_event(socket, "share_trip", %{url: url, title: title})}
  end

  def handle_event("share_trip", _params, socket), do: {:noreply, socket}

  def handle_event("update_profile", %{"user" => user_params}, socket) do
    # The email address is deliberately not editable here: changing it requires
    # a code sent to the new address (see request_email_change below).
    user_params = Map.drop(user_params, ["email"])

    case Accounts.update_user(socket.assigns.user, user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:user, user)
         |> assign(:profile_form, Accounts.change_user(user) |> to_form())
         |> put_flash(:info, "Profile updated successfully")}

      {:error, changeset} ->
        {:noreply, assign(socket, :profile_form, to_form(changeset))}
    end
  end

  def handle_event("open_email_change", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_email_change_modal, true)
     |> assign(:email_change_step, :email)
     |> assign(:email_change_form, to_form(%{"new_email" => ""}))
     |> assign(:email_change_error, nil)
     |> assign(:pending_new_email, nil)}
  end

  def handle_event("close_email_change", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_email_change_modal, false)
     |> assign(:email_change_step, :email)
     |> assign(:email_change_form, to_form(%{"new_email" => ""}))
     |> assign(:email_change_error, nil)
     |> assign(:pending_new_email, nil)}
  end

  def handle_event("request_email_change", %{"email_change" => params}, socket) do
    new_email = params |> Map.get("new_email", "") |> to_string()

    case Accounts.request_email_change(socket.assigns.user, new_email) do
      {:ok, %{new_email: pending}} ->
        {:noreply,
         socket
         |> assign(:email_change_step, :code)
         |> assign(:pending_new_email, pending)
         |> assign(:email_change_error, nil)
         |> put_flash(:info, "We emailed a 6-digit code to #{pending}.")}

      {:error, reason} ->
        {:noreply, assign(socket, :email_change_error, email_change_error(reason))}
    end
  end

  def handle_event("confirm_email_change", %{"code" => code}, socket) do
    case Accounts.verify_email_change(socket.assigns.user, to_string(code)) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:user, user)
         |> assign(:profile_form, Accounts.change_user(user) |> to_form())
         |> assign(:show_email_change_modal, false)
         |> assign(:email_change_step, :email)
         |> assign(:pending_new_email, nil)
         |> assign(:email_change_error, nil)
         |> put_flash(:info, "Email address updated successfully.")}

      {:error, reason} ->
        {:noreply, assign(socket, :email_change_error, email_change_error(reason))}
    end
  end

  def handle_event("save_missing_phone", %{"phone" => phone}, socket) do
    phone = String.trim(phone || "")

    cond do
      phone == "" ->
        {:noreply, assign(socket, :phone_error, "Phone number is required.")}

      not Regex.match?(~r/^(07|01|254)\d{8}$/, phone) ->
        {:noreply, assign(socket, :phone_error, "Please enter a valid Kenyan phone number.")}

      Accounts.get_user_by_phone(phone) ->
        {:noreply,
         assign(socket, :phone_error, "This phone number is already linked to another account.")}

      true ->
        case Accounts.update_user(socket.assigns.user, %{phone: phone}) do
          {:ok, user} ->
            {:noreply,
             socket
             |> assign(:user, user)
             |> assign(:current_user, user.phone)
             |> assign(:show_phone_modal, false)
             |> put_flash(:info, "Phone number updated successfully.")}

          {:error, _changeset} ->
            {:noreply, assign(socket, :phone_error, "Failed to update phone number.")}
        end
    end
  end

  def handle_event("referral_copied", _params, socket) do
    {:noreply, put_flash(socket, :info, "Referral code copied to clipboard.")}
  end

  def handle_event("referral_copy_failed", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       "Could not copy automatically. Long-press the code to copy it."
     )}
  end

  def handle_event("wallet_action", %{"action" => action}, socket) do
    message =
      case action do
        "top-up" ->
          "Wallet top-up is coming soon. For now, pay for each ticket directly at checkout."

        "transfer" ->
          "Wallet transfers are coming soon."

        "change-payment-method" ->
          "You can choose a payment method on every booking at checkout."

        _ ->
          "This feature is coming soon."
      end

    {:noreply, put_flash(socket, :info, message)}
  end

  def handle_event("change_footer_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :footer_tab, tab)}
  end

  defp ticket_belongs_to_user?(ticket, user) do
    identity = user.phone

    is_binary(identity) and identity != "" and
      (ticket.passenger_phone == identity or ticket.passenger_name == identity)
  end

  # All bus bookings that belong to this account. A booking may be linked to the
  # user either by passenger phone (in any common Kenyan format) or by the
  # payment attempt that the signed-in user started, which is how bookings made
  # for a different passenger still show up in the booker's dashboard.
  defp list_user_tickets(%{id: user_id, phone: phone}) do
    variants = phone_variants(phone)

    paid_ticket_ids =
      from(p in Payment,
        where:
          fragment(
            "JSON_UNQUOTE(JSON_EXTRACT(?, '$.booking_context.user_id')) = ?",
            p.raw_response,
            ^to_string(user_id)
          ),
        select: p.ticket_id
      )
      |> Repo.all()
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    from(t in Ticket,
      where: t.passenger_phone in ^variants or t.ticket_id in ^paid_ticket_ids,
      order_by: [desc: t.inserted_at]
    )
    |> Repo.all()
    |> Enum.map(&Tickets.deserialize_seats/1)
  end

  defp phone_variants(phone) do
    digits = String.replace(to_string(phone || ""), ~r/[^0-9]/, "")

    local =
      cond do
        String.starts_with?(digits, "254") -> "0" <> String.trim_leading(digits, "254")
        String.starts_with?(digits, "0") -> digits
        digits != "" -> "0" <> digits
        true -> ""
      end

    international =
      cond do
        String.starts_with?(digits, "254") -> digits
        String.starts_with?(digits, "0") -> "254" <> String.trim_leading(digits, "0")
        digits != "" -> "254" <> digits
        true -> ""
      end

    [phone, digits, local, international, "+" <> international]
    |> Enum.reject(&(&1 in [nil, "", "+"]))
    |> Enum.uniq()
  end

  defp format_date(nil), do: ""
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%B %d, %Y")
  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y • %I:%M %p")

  defp format_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> Calendar.strftime(date, "%B %d, %Y")
      _ -> date_string
    end
  end

  defp format_seats(nil), do: ""
  defp format_seats(seats) when is_list(seats), do: Enum.join(seats, ", ")

  defp format_seats(seats) when is_binary(seats) do
    case Jason.decode(seats) do
      {:ok, decoded_list} when is_list(decoded_list) -> Enum.join(decoded_list, ", ")
      _ -> seats
    end
  end

  defp email_change_error(reason) do
    case reason do
      :invalid_email ->
        "Enter a valid email address."

      :same_email ->
        "That is already your account email."

      :taken ->
        "That email is already linked to another account."

      :delivery_failed ->
        "We could not send the verification email. Please try again."

      :no_code ->
        "Request a new verification code."

      :expired ->
        "That code has expired. Request a new one."

      :too_many_attempts ->
        "Too many incorrect attempts. Request a new code."

      :invalid ->
        "That code is not correct. Check the new email address and try again."

      :failed ->
        "We could not update your email. Please try again."

      {:cooldown, _user} ->
        "A code was just sent. Please wait #{Accounts.email_change_resend_seconds()} seconds before requesting another."

      {:rate_limited, _user} ->
        "Too many email-change requests. Please try again later."

      _reason ->
        "Something went wrong. Please try again."
    end
  end

  # ----------------------------------------------------- My Chyllz account tab

  # The Chyllz tab is lazy: nothing is queried and no weather request is made
  # until the traveller opens it (through `?tab=chyllz` or the tab menu).
  defp maybe_load_chyllz_account(socket, user) do
    if socket.assigns.active_tab == "chyllz" and is_nil(socket.assigns[:chyllz_overview]) do
      load_chyllz_account(socket, user)
    else
      socket
    end
  end

  defp load_chyllz_account(socket, user) do
    overview = ChyllzAccount.overview(user)

    socket
    |> assign(:chyllz_overview, overview)
    |> assign(:chyllz_trips, overview.recent_trips)
    |> assign(:hotel_bookings, overview.hotel_bookings)
    |> assign(:member_since, member_since(user))
    |> assign(:weather_query, overview.default_city)
    |> assign(:weather_city, overview.default_city)
    |> assign(:weather, nil)
    |> assign(:weather_error, nil)
    |> assign(:weather_loading, true)
    |> assign(:weather_chart, empty_chart())
    |> load_weather(overview.default_city, async: true)
  end

  # The first forecast is fetched after the page is interactive so the account
  # page never waits on the network; the static (pre-websocket) render shows the
  # skeleton only.
  defp load_weather(socket, query, opts \\ []) do
    cond do
      Keyword.get(opts, :async, false) and not connected?(socket) ->
        assign(socket,
          weather: nil,
          weather_error: nil,
          weather_loading: true,
          weather_chart: empty_chart()
        )

      Keyword.get(opts, :async, false) and live_weather?() ->
        send(self(), {:load_weather, query})

        assign(socket,
          weather: nil,
          weather_error: nil,
          weather_loading: true,
          weather_chart: empty_chart()
        )

      true ->
        fetch_weather(socket, query)
    end
  end

  defp fetch_weather(socket, query) do
    case Weather.load(query) do
      {:ok, forecast} ->
        socket
        |> assign(:weather, forecast)
        |> assign(:weather_city, forecast.location.name)
        |> assign(:weather_error, nil)
        |> assign(:weather_loading, false)
        |> assign(:weather_chart, chart_for(forecast.hourly))

      {:error, reason} ->
        socket
        |> assign(:weather, nil)
        |> assign(:weather_error, weather_error_message(reason))
        |> assign(:weather_loading, false)
        |> assign(:weather_chart, empty_chart())
    end
  end

  defp live_weather? do
    Weather.enabled?() and
      is_nil(Application.get_env(:xpressbus, :weather_forecast_override))
  end

  defp normalize_tab(tab) do
    tab = to_string(tab)
    if tab in @tabs, do: tab, else: "bus"
  end

  defp tab_path("bus"), do: "/dashboard"
  defp tab_path(tab), do: "/dashboard?tab=" <> tab
end
