defmodule Xpressbus.AgentKpis do
  @moduledoc """
  Live monthly "Achieved" values for the Agent KPI scorecard.

  The monthly targets are set by the partnerships team. This module only reads
  the platform data that can be measured automatically; figures are scoped to
  the current Africa/Nairobi calendar month.
  """

  import Ecto.Query

  alias Xpressbus.Accounts.User
  alias Xpressbus.Agents.AgentApplication
  alias Xpressbus.AgentDashboard
  alias Xpressbus.BusOperators.BusOperator
  alias Xpressbus.Repo

  @doc "Returns the current month's achieved values for an agent."
  def for_agent(%AgentApplication{} = agent) do
    {month_start, previous_month_start} = month_boundaries()

    booking_metrics =
      AgentDashboard.monthly_booking_metrics(agent, month_start, previous_month_start)

    %{
      new_operators:
        count_since(
          from(o in BusOperator, where: o.inserted_at >= ^month_start),
          :id
        ),
      new_agents:
        count_since(
          from(a in AgentApplication,
            where: a.status == "approved" and a.reviewed_at >= ^month_start
          ),
          :id
        ),
      new_passengers:
        count_since(
          from(u in User, where: u.inserted_at >= ^month_start),
          :id
        ),
      booking_growth: growth_label(booking_metrics.previous_sales, booking_metrics.current_sales),
      retention: retention_label(agent)
    }
  end

  defp count_since(query, field), do: Repo.aggregate(query, :count, field)

  defp retention_label(%AgentApplication{bus_operator: %BusOperator{active: true}}),
    do: "0 churn"

  defp retention_label(%AgentApplication{bus_operator: %BusOperator{active: false}}),
    do: "1 churn"

  defp retention_label(%AgentApplication{}), do: "—"

  defp growth_label(previous, current) when previous <= 0 and current <= 0, do: "0% MoM"

  defp growth_label(previous, current) when previous <= 0 and current > 0, do: "New MoM"

  defp growth_label(previous, current) do
    growth = round((current - previous) * 100 / previous)
    sign = if growth > 0, do: "+", else: ""
    "#{sign}#{growth}% MoM"
  end

  # Kenya is UTC+3. A month starts at 00:00 EAT = 21:00 UTC on the previous day.
  defp month_boundaries do
    today = AgentDashboard.local_date()
    current_date = Date.new!(today.year, today.month, 1)

    {previous_year, previous_month} =
      if(today.month == 1, do: {today.year - 1, 12}, else: {today.year, today.month - 1})

    previous_date = Date.new!(previous_year, previous_month, 1)

    {
      DateTime.new!(current_date, ~T[00:00:00], "Etc/UTC")
      |> DateTime.add(-3 * 3600, :second),
      DateTime.new!(previous_date, ~T[00:00:00], "Etc/UTC")
      |> DateTime.add(-3 * 3600, :second)
    }
  end
end
