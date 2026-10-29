defmodule XpressbusWeb.AdminCouponLive do
  use XpressbusWeb, :live_view
  import XpressbusWeb.AdminComponents
  alias Xpressbus.Coupons

  def mount(_params, session, socket) do
    admin_id = session["admin_id"]

    if admin_id do
      page = 1
      page_size = 10
      total_count = Coupons.count_coupons()

      {:ok,
       socket
       |> assign(:page_title, "Coupon Management")
       |> assign(:active_tab, "coupons")
       |> assign(:page, page)
       |> assign(:page_size, page_size)
       |> assign(:total_count, total_count)
       |> assign(:sidebar_collapsed, false)
       |> assign(:bus_expanded, true)
       |> assign(:chyllz_expanded, true)
       |> assign(:settings_expanded, true)
       |> assign(:coupons, Coupons.list_coupons())
       |> assign(:show_modal, false)
       |> assign(:editing_coupon, nil)
       |> assign(:form, to_form(%{}))
       |> assign(:error, nil)}
    else
      {:ok,
       socket
       |> Phoenix.LiveView.redirect(to: ~p"/admin/login")}
    end
  end

  def handle_event("open_add_modal", _params, socket) do
    changeset = Coupons.change_coupon(%Xpressbus.Coupons.Coupon{active: true, type: "percentage"})

    {:noreply,
     socket
     |> assign(:show_modal, true)
     |> assign(:editing_coupon, nil)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :show_modal, false)}
  end

  def handle_event("edit_coupon", %{"id" => id}, socket) do
    coupon = Coupons.get_coupon!(id)
    changeset = Coupons.change_coupon(coupon)

    {:noreply,
     socket
     |> assign(:show_modal, true)
     |> assign(:editing_coupon, coupon)
     |> assign(:form, to_form(changeset))}
  end

  def handle_event("validate_coupon", %{"coupon" => coupon_params}, socket) do
    changeset =
      case socket.assigns.editing_coupon do
        nil -> Coupons.change_coupon(%Xpressbus.Coupons.Coupon{}, coupon_params)
        coupon -> Coupons.change_coupon(coupon, coupon_params)
      end
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save_coupon", %{"coupon" => coupon_params}, socket) do
    case socket.assigns.editing_coupon do
      nil ->
        case Coupons.create_coupon(coupon_params) do
          {:ok, _coupon} ->
            {:noreply,
             socket
             |> put_flash(:info, "Coupon created successfully")
             |> assign(:show_modal, false)
             |> assign(:coupons, Coupons.list_coupons())}

          {:error, changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end

      coupon ->
        case Coupons.update_coupon(coupon, coupon_params) do
          {:ok, _updated} ->
            {:noreply,
             socket
             |> put_flash(:info, "Coupon updated successfully")
             |> assign(:show_modal, false)
             |> assign(:coupons, Coupons.list_coupons())}

          {:error, changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end
    end
  end

  def handle_event("delete_coupon", %{"id" => id}, socket) do
    coupon = Coupons.get_coupon!(id)
    {:ok, _} = Coupons.delete_coupon(coupon)

    {:noreply,
     socket
     |> put_flash(:info, "Coupon deleted")
     |> assign(:coupons, Coupons.list_coupons())}
  end

  def handle_event("toggle_active", %{"id" => id}, socket) do
    coupon = Coupons.get_coupon!(id)
    {:ok, _} = Coupons.update_coupon(coupon, %{active: !coupon.active})
    {:noreply, assign(socket, :coupons, Coupons.list_coupons())}
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
end
