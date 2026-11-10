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
    today = AgentDashboard.local_date()
    period_label = Calendar.strftime(today, "%B %Y")
    previous_period_label = Calendar.strftime(previous_month_start, "%B %Y")

    booking_metrics =
      AgentDashboard.monthly_booking_metrics(agent, month_start, previous_month_start)

    %{
      period_label: period_label,
      previous_period_label: previous_period_label,
      new_operators:
        metric(
          count_since(
            from(o in BusOperator, where: o.inserted_at >= ^month_start),
            :id
          ),
          :platform,
          "New bus operators added across Komiuta in #{period_label}."
        ),
      new_agents:
        metric(
          count_since(
            from(a in AgentApplication,
              where: a.status == "approved" and a.reviewed_at >= ^month_start
            ),
            :id
          ),
          :platform,
          "Agent applications approved across Komiuta in #{period_label}."
        ),
      new_passengers:
        metric(
          count_since(
            from(u in User, where: u.inserted_at >= ^month_start),
            :id
          ),
          :platform,
          "New traveller accounts created across Komiuta in #{period_label}. Agent code attribution is not tracked yet."
        ),
      booking_growth:
        metric(
          growth_label(booking_metrics.previous_sales, booking_metrics.current_sales),
          :partner,
          "Confirmed booking revenue for your assigned partner in #{period_label}, compared with #{previous_period_label}."
        ),
      retention:
        metric(
          retention_label(agent),
          :partner,
          "Active status of your assigned bus partner in #{period_label}."
        )
    }
  end

  defp metric(value, scope, definition) do
    %{
      value: value,
      scope: scope,
      scope_label: if(scope == :platform, do: "Platform-wide", else: "Your partner"),
      scope_short: if(scope == :platform, do: "Platform", else: "Partner"),
      definition: definition
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
