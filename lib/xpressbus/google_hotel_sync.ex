defmodule Xpressbus.GoogleHotelSync do
  @moduledoc """
  Refreshes Google Places data for the curated Chyllz hotels every two days.

  The refresh runs from three places so it works even when nobody is browsing:

    * a scheduler inside the web app (checks at boot and every few hours),
    * the hotels page itself (a due check runs in the background on page load),
    * a scheduled GitHub Actions job that requests the hotels page every two
      days, waking a sleeping Render instance.

  Every completed refresh is recorded in `hotel_sync_runs` and an email report
  is sent to the operations inbox. Email delivery is best-effort and never
  blocks the refresh itself.
  """

  import Ecto.Query
  require Logger

  alias Xpressbus.Repo
  alias Xpressbus.Bookings.{HiddenGem, HiddenGemGoogle, Hotel, HotelGoogle, HotelSyncRun}
  alias Xpressbus.HotelSyncEmail

  @interval_seconds 2 * 24 * 60 * 60

  @doc "Whether the background hotel sync is enabled in this environment."
  def enabled? do
    Application.get_env(:xpressbus, :hotel_sync_enabled, true)
  end

  @doc "True when no refresh has happened in the last two days."
  def due? do
    case last_run() do
      nil -> true
      run -> DateTime.diff(DateTime.utc_now(), run.inserted_at, :second) >= @interval_seconds
    end
  end

  @doc "Runs the refresh only when the two-day window has elapsed."
  def run_if_due do
    if due?(), do: run(), else: {:skipped, :fresh}
  end

  @doc "Starts a due-check in a detached process (used by page loads)."
  def run_if_due_async do
    if enabled?() do
      Task.start(fn -> run_if_due() end)
      :ok
    else
      :disabled
    end
  end

  @doc "Refreshes every active hotel from Google Places and emails a report."
  def run(opts \\ []) do
    if not Keyword.get(opts, :force, false) and not due?() do
      {:skipped, :fresh}
    else
      case :global.trans({__MODULE__, :run}, fn -> do_run() end) do
        :aborted -> {:skipped, :locked}
        result -> result
      end
    end
  end

  defp do_run do
    hotels = Repo.all(from(h in Hotel, where: h.active == true, order_by: [asc: h.name]))
    gems = Repo.all(from(g in HiddenGem, where: g.active == true, order_by: [asc: g.title]))

    enriched_hotels = HotelGoogle.enrich(hotels, force: true)
    enriched_gems = HiddenGemGoogle.enrich(gems, force: true)

    hotels_matched = matched_count(enriched_hotels)
    gems_matched = matched_count(enriched_gems)
    total = length(enriched_hotels) + length(enriched_gems)
    matched = hotels_matched + gems_matched

    status =
      cond do
        total > 0 and matched == total -> "success"
        matched > 0 -> "partial"
        true -> "failed"
      end

    details =
      [
        "Hotels:",
        place_lines(enriched_hotels),
        "",
        "Hidden gems:",
        place_lines(enriched_gems)
      ]
      |> Enum.join("\n")

    {:ok, run} =
      %HotelSyncRun{}
      |> HotelSyncRun.changeset(%{
        status: status,
        hotels_count: length(enriched_hotels),
        matched_count: hotels_matched,
        gems_count: length(enriched_gems),
        gems_matched_count: gems_matched,
        details: details
      })
      |> Repo.insert()

    Logger.info(
      "Google places sync finished: #{status} hotels #{hotels_matched}/#{length(enriched_hotels)}, gems #{gems_matched}/#{length(enriched_gems)}"
    )

    HotelSyncEmail.deliver(run)
    {:ok, run}
  rescue
    error ->
      Logger.error("Google places sync failed: #{Exception.format(:error, error, __STACKTRACE__)}")

      {:ok, run} =
        %HotelSyncRun{}
        |> HotelSyncRun.changeset(%{
          status: "failed",
          hotels_count: 0,
          matched_count: 0,
          gems_count: 0,
          gems_matched_count: 0,
          details: Exception.message(error)
        })
        |> Repo.insert()

      HotelSyncEmail.deliver(run)
      {:ok, run}
  end

  defp matched_count(places) do
    Enum.count(places, &(is_binary(&1.google_place_id) and &1.google_place_id != ""))
  end

  defp place_lines([]), do: "  (none)"

  defp place_lines(places) do
    places
    |> Enum.map(fn place ->
      name = Map.get(place, :name) || Map.get(place, :title)
      rating = Map.get(place, :rating)
      reviews = Map.get(place, :review_count)

      if is_binary(place.google_place_id) do
        "  #{name}: matched (rating #{rating}, #{reviews} reviews)"
      else
        "  #{name}: no confident Google match"
      end
    end)
    |> Enum.join("\n")
  end

  defp last_run do
    Repo.one(from(r in HotelSyncRun, order_by: [desc: r.inserted_at], limit: 1))
  end
end
