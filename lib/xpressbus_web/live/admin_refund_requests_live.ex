defmodule XpressbusWeb.AdminRefundRequestsLive do
  use XpressbusWeb, :live_view

  import XpressbusWeb.AdminComponents

  alias Xpressbus.Refunds

  @page_size 20

  def mount(_params, session, socket) do
    if session["admin_id"] do
      socket =
        socket
        |> assign(:page_title, "Refund requests")
        |> assign(:active_tab, "refunds")
        |> assign(:admin_id, session["admin_id"])
        |> assign(:sidebar_collapsed, false)
        |> assign(:bus_expanded, true)
        |> assign(:chyllz_expanded, false)
        |> assign(:settings_expanded, true)
        |> assign(:selected, nil)
        |> assign(:review_mode, nil)
        |> reload()

      {:ok, socket}
    else
      {:ok, redirect(socket, to: ~p"/admin/login")}
    end
  end

  def handle_event("review", %{"id" => id, "mode" => mode}, socket) do
    refund = Refunds.get_refund(id)

    {:noreply,
     assign(socket,
       selected: refund,
       review_mode: if(refund, do: mode, else: nil)
     )}
  end

  def handle_event("close_review", _params, socket) do
    {:noreply, assign(socket, selected: nil, review_mode: nil)}
  end

  def handle_event("approve", params, socket) do
    id = params["refund_id"] || params["id"]

    case Refunds.get_refund(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "That refund request no longer exists.")}

      refund ->
        case Refunds.approve(refund, socket.assigns.admin_id, params["refund"] || %{}) do
          {:ok, _refund} ->
            {:noreply,
             socket
             |> put_flash(:success, "Refund approved.")
             |> assign(selected: nil, review_mode: nil)
             |> reload()}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, error_message(reason))}
        end
    end
  end

  def handle_event("reject", params, socket) do
    id = params["refund_id"] || params["id"]

    case Refunds.get_refund(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "That refund request no longer exists.")}

      refund ->
        case Refunds.reject(refund, socket.assigns.admin_id, params["refund"] || %{}) do
          {:ok, _refund} ->
            {:noreply,
             socket
             |> put_flash(:success, "Refund request declined.")
             |> assign(selected: nil, review_mode: nil)
             |> reload()}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, error_message(reason))}
        end
    end
  end

  def handle_event("mark_refunded", params, socket) do
    id = params["refund_id"] || params["id"]

    case Refunds.get_refund(id) do
      nil ->
        {:noreply, put_flash(socket, :error, "That refund request no longer exists.")}

      refund ->
        case Refunds.mark_refunded(refund, socket.assigns.admin_id, params["refund"] || %{}) do
          {:ok, _refund} ->
            {:noreply,
             socket
             |> put_flash(:success, "Refund marked as paid and the ticket cancelled.")
             |> assign(selected: nil, review_mode: nil)
             |> reload()}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, error_message(reason))}
        end
    end
  end

  defp reload(socket) do
    {history, total} = Refunds.paginate(1, @page_size)

    socket
    |> assign(:requests, Refunds.open_requests())
    |> assign(:history, history)
    |> assign(:total, total)
    |> assign(:stats, Refunds.stats())
  end

  defp error_message(:invalid_transition), do: "This request has already been decided."

  defp error_message(:invalid_amount),
    do: "The approved amount must be between 1 and the requested amount."

  defp error_message(:reason_required), do: "Add a short reason before declining."

  defp error_message(:reference_required),
    do: "Enter the payment provider reference before marking it paid."

  defp error_message(_reason), do: "That action could not be completed."
end
