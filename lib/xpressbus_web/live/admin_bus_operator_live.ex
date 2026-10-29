defmodule XpressbusWeb.AdminBusOperatorLive do
  use XpressbusWeb, :live_view
  import XpressbusWeb.AdminComponents
  alias Xpressbus.BusOperators

  def mount(_params, session, socket) do
    admin_id = session["admin_id"]

    if admin_id do
      page = 1
      page_size = 10
      total_count = BusOperators.count_bus_operators()

      {:ok,
       socket
       |> assign(:page_title, "Bus Operators")
       |> assign(:active_tab, "operators")
       |> assign(:page, page)
       |> assign(:page_size, page_size)
       |> assign(:total_count, total_count)
       |> assign(:sidebar_collapsed, false)
       |> assign(:bus_expanded, true)
       |> assign(:chyllz_expanded, true)
       |> assign(:settings_expanded, true)
       |> assign(:bus_operators, BusOperators.paginate_bus_operators(page, page_size))
       |> assign(:show_modal, false)
       |> assign(:show_delete_modal, false)
       |> assign(:delete_id, nil)
       |> assign(:editing_operator, nil)
       |> assign(:operator_name, "")
       |> assign(:contact_person, "")
       |> assign(:phone, "")
       |> assign(:email, "")
       |> assign(:logo_url, "")
       |> assign(:active, true)
       |> assign(:search_query, "")
       |> assign(:error, nil)}
    else
      {:ok,
       socket
       |> assign(:page_title, "Bus Operators")
       |> Phoenix.LiveView.redirect(to: ~p"/admin/login")}
    end
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    page = String.to_integer(page)
    page_size = socket.assigns.page_size

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:bus_operators, BusOperators.paginate_bus_operators(page, page_size))}
  end

  def handle_event("open_add_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, true)
     |> assign(:editing_operator, nil)
     |> assign(:operator_name, "")
     |> assign(:contact_person, "")
     |> assign(:phone, "")
     |> assign(:email, "")
     |> assign(:logo_url, "")
     |> assign(:active, true)
     |> assign(:error, nil)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:editing_operator, nil)
     |> assign(:error, nil)}
  end

  def handle_event("edit_operator", %{"id" => id}, socket) do
    operator = Enum.find(socket.assigns.bus_operators, &(&1.id == String.to_integer(id)))

    if operator do
      {:noreply,
       socket
       |> assign(:show_modal, true)
       |> assign(:editing_operator, operator)
       |> assign(:operator_name, operator.name)
       |> assign(:contact_person, operator.contact_person || "")
       |> assign(:phone, operator.phone || "")
       |> assign(:email, operator.email || "")
       |> assign(:logo_url, operator.logo_url || "")
       |> assign(:active, operator.active)
       |> assign(:error, nil)}
    else
      {:noreply, assign(socket, :error, "Operator not found")}
    end
  end

  def handle_event("delete_operator", %{"id" => id}, socket) do
    case BusOperators.list_bus_operators() do
      operators when length(operators) <= 1 ->
        {:noreply, assign(socket, :error, "Cannot delete the last bus operator")}

      _ ->
        {:noreply,
         socket
         |> assign(:show_delete_modal, true)
         |> assign(:delete_id, String.to_integer(id))
         |> assign(:error, nil)}
    end
  end

  def handle_event("confirm_delete", _params, socket) do
    operator = Enum.find(socket.assigns.bus_operators, &(&1.id == socket.assigns.delete_id))

    if operator do
      Xpressbus.Repo.delete!(operator)

      {:noreply,
       socket
       |> assign(:bus_operators, BusOperators.list_bus_operators())
       |> assign(:show_delete_modal, false)
       |> assign(:delete_id, nil)
       |> assign(:error, nil)
       |> put_flash(:success, "Bus operator deleted successfully")}
    else
      {:noreply,
       socket
       |> assign(:show_delete_modal, false)
       |> assign(:delete_id, nil)
       |> assign(:error, "Operator not found")}
    end
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_delete_modal, false)
     |> assign(:delete_id, nil)
     |> assign(:error, nil)}
  end

  def handle_event(
        "save_operator",
        %{
          "operator_name" => name,
          "contact_person" => contact_person,
          "phone" => phone,
          "email" => email,
          "logo_url" => logo_url,
          "active" => active_value
        },
        socket
      ) do
    name = String.trim(name || "")
    contact_person = String.trim(contact_person || "")
    phone = String.trim(phone || "")
    email = String.trim(email || "")
    logo_url = String.trim(logo_url || "")
    active = active_value == "true"

    if name == "" do
      {:noreply, assign(socket, :error, "Operator name is required")}
    else
      attrs = %{
        name: name,
        contact_person: contact_person,
        phone: phone,
        email: email,
        logo_url: logo_url,
        active: active
      }

      if socket.assigns.editing_operator do
        operator = socket.assigns.editing_operator
        changeset = Ecto.Changeset.change(operator, attrs)
        {:ok, _updated} = Xpressbus.Repo.update!(changeset)

        {:noreply,
         socket
         |> assign(:bus_operators, BusOperators.list_bus_operators())
         |> assign(:show_modal, false)
         |> assign(:editing_operator, nil)
         |> assign(:error, nil)
         |> put_flash(:success, "Bus operator updated successfully")}
      else
        case BusOperators.create_bus_operator(attrs) do
          {:ok, _operator} ->
            {:noreply,
             socket
             |> assign(:bus_operators, BusOperators.list_bus_operators())
             |> assign(:show_modal, false)
             |> assign(:operator_name, "")
             |> assign(:contact_person, "")
             |> assign(:phone, "")
             |> assign(:email, "")
             |> assign(:logo_url, "")
             |> assign(:active, true)
             |> assign(:editing_operator, nil)
             |> assign(:error, nil)
             |> put_flash(:success, "Bus operator added successfully")}

          {:error, _changeset} ->
            {:noreply, assign(socket, :error, "Failed to add bus operator")}
        end
      end
    end
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

  def handle_event("search", %{"search_query" => query}, socket) do
    query = String.trim(query || "")
    operators = BusOperators.list_bus_operators()

    filtered =
      if query != "" do
        pattern = String.downcase(query)

        Enum.filter(operators, fn op ->
          String.downcase(op.name) =~ pattern or
            String.downcase(op.contact_person || "") =~ pattern or
            String.downcase(op.phone || "") =~ pattern or
            String.downcase(op.email || "") =~ pattern
        end)
      else
        operators
      end

    {:noreply,
     socket
     |> assign(:bus_operators, filtered)
     |> assign(:search_query, query)}
  end

  defp initials_color(name) do
    hash = :erlang.phash2(name)

    colors = [
      "bg-[#FF4C00]",
      "bg-emerald-500",
      "bg-blue-500",
      "bg-purple-500",
      "bg-pink-500",
      "bg-teal-500",
      "bg-orange-500",
      "bg-amber-500"
    ]

    Enum.at(colors, rem(hash, length(colors)))
  end
end
