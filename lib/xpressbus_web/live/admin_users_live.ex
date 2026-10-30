defmodule XpressbusWeb.AdminUsersLive do
  use XpressbusWeb, :live_view
  import XpressbusWeb.AdminComponents

  alias Xpressbus.{Accounts, Tickets}

  @page_size 15

  def mount(_params, session, socket) do
    if session["admin_id"] do
      socket =
        socket
        |> assign(:page_title, "User/Agent List")
        |> assign(:active_tab, "users")
        |> assign(:page_size, @page_size)
        |> assign(:search, "")
        |> assign(:sidebar_collapsed, false)
        |> assign(:bus_expanded, true)
        |> assign(:chyllz_expanded, true)
        |> assign(:settings_expanded, true)
        |> load_users(1, "")

      {:ok, socket}
    else
      {:ok, Phoenix.LiveView.redirect(to: ~p"/admin/login")}
    end
  end

  def handle_event("search", %{"search" => search}, socket) do
    search = to_string(search || "")
    {:noreply, socket |> assign(:search, search) |> load_users(1, search)}
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    page = page |> to_string() |> String.to_integer() |> max(1)
    {:noreply, load_users(socket, page, socket.assigns.search)}
  end

  def handle_event("toggle_bus", %{"category" => "bus"}, socket) do
    {:noreply, assign(socket, :bus_expanded, !socket.assigns.bus_expanded)}
  end

  def handle_event("toggle_chyllz", %{"category" => "chyllz"}, socket) do
    {:noreply, assign(socket, :chyllz_expanded, !socket.assigns.chyllz_expanded)}
  end

  def handle_event("toggle_settings", %{"category" => "settings"}, socket) do
    {:noreply, assign(socket, :settings_expanded, !socket.assigns.settings_expanded)}
  end

  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :sidebar_collapsed, !socket.assigns.sidebar_collapsed)}
  end

  defp load_users(socket, page, search) do
    {users, total_count} = Accounts.paginate_users(page, socket.assigns.page_size, search)
    ticket_counts = Tickets.counts_by_passenger_phones(Enum.map(users, & &1.phone))

    rows =
      Enum.map(users, fn user ->
        %{
          id: user.id,
          name: user.name || "Unnamed user",
          initials: initials(user.name),
          phone: user.phone,
          email: user.email,
          signed_up: user.inserted_at,
          tickets: Map.get(ticket_counts, user.phone, 0),
          wallet: money(user.wallet_balance),
          login_ready: Accounts.profile_complete?(user)
        }
      end)

    socket
    |> assign(:users, rows)
    |> assign(:total_count, total_count)
    |> assign(:page, page)
  end

  defp initials(nil), do: "?"

  defp initials(name) do
    name
    |> to_string()
    |> String.trim()
    |> case do
      "" -> "?"
      value -> value |> String.slice(0, 1) |> String.upcase()
    end
  end

  defp money(nil), do: "0.00"
  defp money(%Decimal{} = value), do: Decimal.to_string(value, :normal)
  defp money(value), do: to_string(value)
end
