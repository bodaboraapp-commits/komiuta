defmodule XpressbusWeb.AdminInsuranceLive do
  @moduledoc """
  Read-only admin view of the InSURE catalogue.

  Mirrors the other Chyllz catalogue admin pages: it lists the database rows
  that back the public insurance page so support/marketing can confirm what is
  live, which plan is highlighted and whether a plan is active.
  """

  use XpressbusWeb, :live_view

  import XpressbusWeb.AdminComponents
  import XpressbusWeb.Format, only: [money: 1]

  alias Xpressbus.Insurance

  def mount(_params, session, socket) do
    if session["admin_id"] do
      {:ok,
       socket
       |> assign(:page_title, "InSURE Plans")
       |> assign(:active_tab, "insurance-plans")
       |> assign(:sidebar_collapsed, false)
       |> assign(:bus_expanded, true)
       |> assign(:chyllz_expanded, true)
       |> assign(:settings_expanded, true)
       |> assign(:plans, Insurance.list_plans())
       |> assign(:plan_count, Insurance.count_plans())
       |> assign(:faq_count, Insurance.count_faqs())}
    else
      {:ok,
       socket
       |> assign(:page_title, "InSURE Plans")
       |> Phoenix.LiveView.redirect(to: ~p"/admin/login")}
    end
  end

  def handle_event("toggle_bus", %{"category" => "bus"}, socket) do
    {:noreply, assign(socket, :bus_expanded, not socket.assigns.bus_expanded)}
  end

  def handle_event("toggle_chyllz", %{"category" => "chyllz"}, socket) do
    {:noreply, assign(socket, :chyllz_expanded, not socket.assigns.chyllz_expanded)}
  end

  def handle_event("toggle_settings", %{"category" => "settings"}, socket) do
    {:noreply, assign(socket, :settings_expanded, not socket.assigns.settings_expanded)}
  end

  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, :sidebar_collapsed, not socket.assigns.sidebar_collapsed)}
  end
end
