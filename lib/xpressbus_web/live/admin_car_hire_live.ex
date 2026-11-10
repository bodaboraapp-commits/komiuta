defmodule XpressbusWeb.AdminCarHireLive do
  use XpressbusWeb, :live_view

  import XpressbusWeb.AdminComponents

  alias Xpressbus.CarHires

  @page_size 10

  def mount(_params, session, socket) do
    if session["admin_id"] do
      {:ok,
       socket
       |> assign(:page_title, "Car Hires")
       |> assign(:active_tab, "cars")
       |> assign(:sidebar_collapsed, false)
       |> assign(:bus_expanded, false)
       |> assign(:chyllz_expanded, true)
       |> assign(:settings_expanded, true)
       |> assign(:page_size, @page_size)
       |> assign(:search_query, "")
       |> assign(:show_modal, false)
       |> assign(:editing_car, nil)
       |> assign(:error, nil)
       |> reset_form()
       |> load_cars(1, "")}
    else
      {:ok,
       socket
       |> assign(:page_title, "Car Hires")
       |> redirect(to: ~p"/admin/login")}
    end
  end

  def handle_event("search", %{"search_query" => query}, socket) do
    query = String.trim(to_string(query || ""))
    {:noreply, socket |> assign(:search_query, query) |> load_cars(1, query)}
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    page = page |> to_string() |> String.to_integer() |> max(1)
    {:noreply, load_cars(socket, page, socket.assigns.search_query)}
  end

  def handle_event("open_add_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, true)
     |> assign(:editing_car, nil)
     |> assign(:error, nil)
     |> reset_form()}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, socket |> assign(:show_modal, false) |> assign(:editing_car, nil)}
  end

  def handle_event("edit_car", %{"id" => id}, socket) do
    case CarHires.get_car_hire(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Car hire not found.")}

      car ->
        {:noreply,
         socket
         |> assign(:show_modal, true)
         |> assign(:editing_car, car)
         |> assign(:error, nil)
         |> assign(:car_name, car.car_name || "")
         |> assign(:car_type, car.type || "")
         |> assign(:location, car.location || "")
         |> assign(:price_per_day, to_string(car.price_per_day))
         |> assign(:active, car.active)}
    end
  end

  def handle_event("save_car", params, socket) do
    attrs = %{
      car_name: String.trim(to_string(params["car_name"] || "")),
      type: String.trim(to_string(params["type"] || "")),
      location: String.trim(to_string(params["location"] || "")),
      price_per_day: String.trim(to_string(params["price_per_day"] || "")),
      active: params["active"] in ["true", true, "on"]
    }

    result =
      case socket.assigns.editing_car do
        nil -> CarHires.create_car_hire(attrs)
        car -> CarHires.update_car_hire(car, attrs)
      end

    case result do
      {:ok, car} ->
        message =
          if socket.assigns.editing_car,
            do: "#{car.car_name} updated.",
            else: "#{car.car_name} added to the car hire list."

        {:noreply,
         socket
         |> assign(:show_modal, false)
         |> assign(:editing_car, nil)
         |> put_flash(:success, message)
         |> load_cars(socket.assigns.page, socket.assigns.search_query)}

      {:error, changeset} ->
        {:noreply, assign(socket, :error, error_message(changeset))}
    end
  end

  def handle_event("toggle_active", %{"id" => id}, socket) do
    car = CarHires.get_car_hire!(id)

    case CarHires.toggle_active(car) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> put_flash(
           :success,
           "#{updated.car_name} is now #{if updated.active, do: "active", else: "inactive"}."
         )
         |> load_cars(socket.assigns.page, socket.assigns.search_query)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update the vehicle.")}
    end
  end

  def handle_event("delete_car", %{"id" => id}, socket) do
    case CarHires.get_car_hire(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Car hire not found.")}

      car ->
        case CarHires.delete_car_hire(car) do
          {:ok, _deleted} ->
            {:noreply,
             socket
             |> put_flash(:success, "#{car.car_name} deleted.")
             |> load_cars(socket.assigns.page, socket.assigns.search_query)}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Could not delete the vehicle.")}
        end
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

  defp load_cars(socket, page, search) do
    {cars, total} = CarHires.paginate_car_hires(page, socket.assigns.page_size, search)

    total_pages = max(1, ceil(total / socket.assigns.page_size))
    page = min(max(page, 1), total_pages)

    {cars, total} =
      if page != socket.assigns[:page] do
        CarHires.paginate_car_hires(page, socket.assigns.page_size, search)
      else
        {cars, total}
      end

    socket
    |> assign(:car_hires, cars)
    |> assign(:total_count, total)
    |> assign(:page, page)
    |> assign(:total_pages, total_pages)
  end

  defp reset_form(socket) do
    socket
    |> assign(:car_name, "")
    |> assign(:car_type, "")
    |> assign(:location, "")
    |> assign(:price_per_day, "")
    |> assign(:active, true)
  end

  defp error_message(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, _opts} -> message end)
    |> Enum.map(fn {field, messages} ->
      "#{Phoenix.Naming.humanize(field)} #{Enum.join(messages, ", ")}"
    end)
    |> Enum.join(". ")
    |> case do
      "" -> "Please check the vehicle details and try again."
      message -> message
    end
  end
end
