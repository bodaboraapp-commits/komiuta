defmodule Mix.Tasks.Komiuta.ClearPendingBookings do
  @shortdoc "Archives and deletes stale pending ticket bookings"

  @moduledoc """
  Clears abandoned "pending" ticket bookings (and the payment attempts linked to
  them) created before a cutoff.

      mix komiuta.clear_pending_bookings --dry-run
      mix komiuta.clear_pending_bookings
      mix komiuta.clear_pending_bookings --before 2026-11-06

  `--before DATE` means "before 00:00 Africa/Nairobi on DATE" and accepts either
  a date (`YYYY-MM-DD`) or an ISO8601 datetime. Without the option the cutoff is
  00:00 today in Africa/Nairobi. Rows are copied into `pending_booking_archive`
  before deletion, so the cleanup is reversible.

  Pending tickets that have a successful payment are never deleted (they are
  paid bookings with an inconsistent status and need investigation instead).
  """

  use Mix.Task

  @impl true
  def run(args) do
    {opts, argv, invalid} =
      OptionParser.parse(args, strict: [before: :string, dry_run: :boolean])

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    if argv != [] do
      Mix.raise("Unexpected arguments: #{inspect(argv)}")
    end

    Mix.Task.run("app.start")

    dry_run? = Keyword.get(opts, :dry_run, false)
    cutoff = cutoff!(opts[:before])

    summary = Xpressbus.DataCleanup.clear_stale_pending_bookings(cutoff, dry_run: dry_run?)

    prefix = if summary.dry_run, do: "[dry-run] would remove", else: "Removed"

    Mix.shell().info(
      "#{prefix} #{summary.tickets} pending ticket(s) and #{summary.payments} linked payment(s) created before #{DateTime.to_iso8601(cutoff)}"
    )

    Mix.shell().info(
      "#{summary.protected} pending ticket(s) kept because they have a successful payment"
    )
  end

  defp cutoff!(nil), do: Xpressbus.DataCleanup.cutoff_for_today()

  defp cutoff!(value) do
    case Date.from_iso8601(value) do
      {:ok, date} ->
        # Before 00:00 Africa/Nairobi on `date` == previous day 21:00 UTC.
        DateTime.new!(Date.add(date, -1), ~T[21:00:00], "Etc/UTC")

      {:error, _reason} ->
        case DateTime.from_iso8601(value) do
          {:ok, datetime, _offset} ->
            datetime

          {:error, _reason} ->
            Mix.raise(
              "Expected --before as YYYY-MM-DD or an ISO8601 datetime, got: #{inspect(value)}"
            )
        end
    end
  end
end
