defmodule XpressbusWeb.AdminAgentApplicationsLive do
  use XpressbusWeb, :live_view
  import XpressbusWeb.AdminComponents

  alias Xpressbus.Agents

  @page_size 20

  def mount(_params, session, socket) do
    if session["admin_id"] do
      socket =
        socket
        |> assign(:page_title, "Agent Applications")
        |> assign(:active_tab, "agents")
        |> assign(:page_size, @page_size)
        |> assign(:search, "")
        |> assign(:sidebar_collapsed, false)
        |> assign(:bus_expanded, false)
        |> assign(:chyllz_expanded, false)
        |> assign(:settings_expanded, true)
        |> load_applications(1, "")

      {:ok, socket}
    else
      {:ok, Phoenix.LiveView.redirect(to: ~p"/admin/login")}
    end
  end

  def handle_event("search", %{"search" => search}, socket) do
    search = to_string(search || "")
    {:noreply, socket |> assign(:search, search) |> load_applications(1, search)}
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    page = page |> to_string() |> String.to_integer() |> max(1)
    {:noreply, load_applications(socket, page, socket.assigns.search)}
  end

  def handle_event("update_status", %{"id" => id, "status" => status}, socket) do
    application = Agents.get_application!(id)

    case Agents.update_status(application, status) do
      {:ok, _application} ->
        message =
          case status do
            "approved" -> "Application approved."
            "rejected" -> "Application rejected."
            _ -> "Application marked pending."
          end

        {:noreply,
         socket
         |> put_flash(:info, message)
         |> load_applications(socket.assigns.page, socket.assigns.search)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update the application.")}
    end
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

  defp load_applications(socket, page, search) do
    {applications, total} = Agents.paginate_applications(page, socket.assigns.page_size, search)

    socket
    |> assign(:applications, applications)
    |> assign(:total_count, total)
    |> assign(:page, page)
    |> assign(:total_pages, max(1, ceil(total / socket.assigns.page_size)))
  end
end
