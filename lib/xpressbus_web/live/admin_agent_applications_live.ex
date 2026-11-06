defmodule XpressbusWeb.AdminAgentApplicationsLive do
  use XpressbusWeb, :live_view
  import XpressbusWeb.AdminComponents

  alias Xpressbus.Agents
  alias Xpressbus.AgentNotifications
  alias Xpressbus.BusOperators

  @page_size 20

  def mount(_params, session, socket) do
    if session["admin_id"] do
      socket =
        socket
        |> assign(:page_title, "Agent Applications")
        |> assign(:active_tab, "agents")
        |> assign(:page_size, @page_size)
        |> assign(:search, "")
        |> assign(:expanded_applications, MapSet.new())
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

  def handle_event("toggle_application", %{"id" => id}, socket) do
    expanded = socket.assigns.expanded_applications

    expanded =
      if MapSet.member?(expanded, id) do
        MapSet.delete(expanded, id)
      else
        MapSet.put(expanded, id)
      end

    {:noreply, assign(socket, :expanded_applications, expanded)}
  end

  def handle_event("update_status", %{"id" => id, "status" => status}, socket) do
    update_agent_status(socket, id, status, nil)
  end

  def handle_event("reject_application", %{"application_id" => id, "reason" => reason}, socket) do
    reason = String.trim(to_string(reason || ""))

    if reason == "" do
      {:noreply, put_flash(socket, :error, "A rejection reason is required.")}
    else
      update_agent_status(socket, id, "rejected", reason)
    end
  end

  def handle_event(
        "assign_bus_operator",
        %{"application_id" => id, "bus_operator_id" => bus_operator_id},
        socket
      ) do
    application = Agents.get_application!(id)

    case Agents.assign_bus_operator(application, bus_operator_id) do
      {:ok, updated} ->
        updated = Agents.get_application_with_bus_operator(updated.id)

        bus_operator_name =
          if(updated.bus_operator, do: updated.bus_operator.name, else: "No bus operator")

        {:noreply,
         socket
         |> put_flash(:success, "Agent assigned to #{bus_operator_name}.")
         |> load_applications(socket.assigns.page, socket.assigns.search)}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :error, "Could not assign the bus operator. Please try again.")}
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

  defp update_agent_status(socket, id, status, reason) do
    application = Agents.get_application!(id)

    case Agents.update_status(application, status, reason) do
      {:ok, updated} ->
        notifications = AgentNotifications.notify(updated, event_for(status), reason)

        message =
          "#{status_message(status)} Email: #{AgentNotifications.label(notifications.email)}. SMS: #{AgentNotifications.label(notifications.sms)}."

        {:noreply,
         socket
         |> put_flash(:info, message)
         |> load_applications(socket.assigns.page, socket.assigns.search)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update the application.")}
    end
  end

  defp event_for("approved"), do: :approved
  defp event_for("rejected"), do: :rejected
  defp event_for(_status), do: :pending

  defp status_message("approved"), do: "Application approved."
  defp status_message("rejected"), do: "Application rejected."
  defp status_message(_status), do: "Application marked pending."

  defp review_title(%{status: "approved"}), do: "Application approved"
  defp review_title(%{status: "rejected"}), do: "Application rejected"
  defp review_title(_application), do: "Awaiting review"

  defp review_dot_class("approved"), do: "bg-emerald-500"
  defp review_dot_class("rejected"), do: "bg-red-500"
  defp review_dot_class(_status), do: "bg-amber-400"

  defp payout_label("mpesa"), do: "M-Pesa"
  defp payout_label("bank"), do: "Bank"
  defp payout_label("card"), do: "Card"
  defp payout_label(other), do: other |> to_string() |> String.capitalize()

  defp load_applications(socket, page, search) do
    {applications, total} = Agents.paginate_applications(page, socket.assigns.page_size, search)

    socket
    |> assign(:applications, applications)
    |> assign(:bus_operators, BusOperators.list_bus_operators())
    |> assign(:total_count, total)
    |> assign(:page, page)
    |> assign(:total_pages, max(1, ceil(total / socket.assigns.page_size)))
  end
end
