defmodule Xpressbus.Analytics do
  @moduledoc """
  First-party funnel analytics.

  We record the handful of events needed to understand the traveller signup,
  AI itinerary and Manage Itinerary journeys. Recording is best-effort: an
  analytics failure must never break signup, saving or payment.
  """

  import Ecto.Query

  alias Xpressbus.Analytics.Event
  alias Xpressbus.Repo

  @funnels [
    %{
      key: "signup",
      title: "Traveller signup",
      description: "From opening signup to a completed traveller account.",
      stages: [
        {"signup_started", "Opened signup"},
        {"signup_phone_verified", "Verified phone"},
        {"signup_details_viewed", "Entered details"},
        {"signup_completed", "Created account"}
      ]
    },
    %{
      key: "ai",
      title: "AI itinerary",
      description: "Itinerary generation, saving and refinement.",
      stages: [
        {"ai_itinerary_generated", "Generated"},
        {"ai_itinerary_saved", "Saved"},
        {"ai_itinerary_refined", "Refined"}
      ]
    },
    %{
      key: "manage",
      title: "Manage Itinerary",
      description: "Opening a trip manager and recording the first budget or expense.",
      stages: [
        {"manage_itinerary_opened", "Opened"},
        {"manage_itinerary_budget_set", "Budget set"},
        {"manage_itinerary_expense_added", "Expense added"}
      ]
    }
  ]

  @doc "The configured GA4 measurement id, or nil when analytics is disabled."
  def measurement_id do
    case Application.get_env(:xpressbus, :analytics, []) do
      config when is_list(config) -> config[:measurement_id]
      _other -> nil
    end
  end

  def funnels, do: @funnels

  @doc "Records a funnel event. Analytics failures are swallowed by design."
  def track(event, opts \\ []) when is_binary(event) do
    attrs = %{
      event: event,
      user_id: Keyword.get(opts, :user_id),
      metadata: Keyword.get(opts, :metadata, %{})
    }

    %Event{}
    |> Event.changeset(attrs)
    |> Repo.insert()
  rescue
    error ->
      require Logger

      Logger.warning(
        "Analytics event #{event} could not be recorded: #{Exception.message(error)}"
      )

      {:error, :analytics_unavailable}
  end

  @doc "Counts every 7/30/90-day funnel stage for the admin report."
  def funnel_report(days \\ 30) do
    since = DateTime.add(DateTime.utc_now(), -days, :day)
    events = Enum.flat_map(@funnels, fn funnel -> Enum.map(funnel.stages, &elem(&1, 0)) end)
    counts = counts_for(events, since)

    Enum.map(@funnels, fn funnel ->
      total = Map.get(counts, elem(hd(funnel.stages), 0), 0)

      stages =
        funnel.stages
        |> Enum.with_index()
        |> Enum.map(fn {{event, label}, index} ->
          count = Map.get(counts, event, 0)

          %{
            event: event,
            label: label,
            count: count,
            conversion: conversion(total, count),
            conversion_label: conversion_label(total, count),
            step_conversion: step_conversion(counts, funnel.stages, index),
            step_conversion_label:
              step_conversion_label(step_conversion(counts, funnel.stages, index), index)
          }
        end)

      funnel
      |> Map.put(:stages, stages)
      |> Map.put(:total, total)
    end)
  end

  defp counts_for(events, since) do
    Repo.all(
      from(event in Event,
        where: event.event in ^events and event.inserted_at >= ^since,
        group_by: event.event,
        select: {event.event, count(event.id)}
      )
    )
    |> Map.new()
  end

  defp conversion(total, _count) when total == 0, do: 0
  defp conversion(total, count), do: round(count / total * 100)

  defp conversion_label(0, _count), do: "—"
  defp conversion_label(total, count), do: "#{conversion(total, count)}%"

  defp step_conversion_label(_value, 0), do: "Start"
  defp step_conversion_label(0, _index), do: "—"
  defp step_conversion_label(value, _index), do: "→ #{value}%"

  defp step_conversion(_counts, _stages, 0), do: 100

  defp step_conversion(counts, stages, index) do
    previous_event = stages |> Enum.at(index - 1) |> elem(0)
    current_event = stages |> Enum.at(index) |> elem(0)
    conversion(Map.get(counts, previous_event, 0), Map.get(counts, current_event, 0))
  end
end
