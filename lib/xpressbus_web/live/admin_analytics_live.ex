defmodule XpressbusWeb.AdminAnalyticsLive do
  use XpressbusWeb, :live_view

  import XpressbusWeb.AdminComponents

  alias Xpressbus.{Analytics, ContentCache}

  @periods [7, 30, 90]

  def mount(_params, session, socket) do
    if session["admin_id"] do
      {:ok,
       socket
       |> assign(:page_title, "Analytics & Funnels")
       |> assign(:active_tab, "analytics")
       |> assign(:periods, @periods)
       |> assign(:days, 30)
       |> assign(:period_label, "Last 30 days")
       |> assign(:ga_measurement_id, Analytics.measurement_id())
       |> assign(:sidebar_collapsed, false)
       |> assign(:bus_expanded, false)
       |> assign(:chyllz_expanded, false)
       |> assign(:settings_expanded, false)
       |> load_funnels()}
    else
      {:ok, redirect(socket, to: ~p"/admin/login")}
    end
  end

  def handle_event("set_period", %{"days" => days}, socket) do
    days = String.to_integer(days)

    if days in @periods do
      {:noreply,
       socket
       |> assign(:days, days)
       |> assign(:period_label, period_label(days))
       |> load_funnels()}
    else
      {:noreply, socket}
    end
  end

  defp load_funnels(socket) do
    days = socket.assigns.days

    funnels =
      ContentCache.fetch(
        {__MODULE__, :funnels, days},
        fn -> Analytics.funnel_report(days) end,
        15_000
      )

    assign(socket, :funnels, funnels)
  end

  defp period_label(7), do: "Last 7 days"
  defp period_label(30), do: "Last 30 days"
  defp period_label(90), do: "Last 90 days"
end
