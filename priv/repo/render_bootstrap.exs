# One-time bootstrap for hosts without shell access (e.g. Render Free).
#
# Creates the admin account on first boot when ADMIN_EMAIL and ADMIN_PASSWORD
# are set in the environment. It is safe to run on every boot: if the account
# already exists it does nothing.
#
# Run order (see render.yaml startCommand):
#   mix ecto.migrate
#   mix run priv/repo/render_bootstrap.exs
#   mix phx.server

alias Xpressbus.Admins

email = System.get_env("ADMIN_EMAIL")
password = System.get_env("ADMIN_PASSWORD")

if is_binary(email) and email != "" and is_binary(password) and password != "" do
  case Admins.get_by_email(email) do
    nil ->
      attrs = %{
        email: email,
        name: System.get_env("ADMIN_NAME", "Administrator"),
        hashed_password: Admins.hash_password(password)
      }

      case Admins.create_admin(attrs) do
        {:ok, admin} ->
          IO.puts("[bootstrap] admin created: #{admin.email}")

        {:error, changeset} ->
          IO.puts("[bootstrap] admin creation failed: #{inspect(changeset.errors)}")
      end

    _admin ->
      IO.puts("[bootstrap] admin already exists: #{email}")
  end
else
  IO.puts("[bootstrap] ADMIN_EMAIL / ADMIN_PASSWORD not set - skipping")
end

# --- One-time data cleanup ---------------------------------------------------
#
# Remove abandoned "pending" ticket bookings created before 2026-11-06
# (00:00 Africa/Nairobi = 2026-11-05 21:00 UTC), together with the payment
# attempts linked to them. The rows are archived into `pending_booking_archive`
# before deletion (see Xpressbus.DataCleanup), so this is reversible.
#
# It is idempotent (nothing is deleted on later boots) and wrapped in a rescue
# so a data problem can never stop the app from booting.
try do
  cutoff = ~U[2026-11-05 21:00:00Z]

  summary = Xpressbus.DataCleanup.clear_stale_pending_bookings(cutoff)

  IO.puts(
    "[bootstrap] cleared stale pending bookings: #{summary.tickets} ticket(s), " <>
      "#{summary.payments} linked payment(s) archived; " <>
      "#{summary.protected} paid-but-pending ticket(s) kept for review"
  )
rescue
  error ->
    IO.puts("[bootstrap] stale pending booking cleanup skipped: #{Exception.message(error)}")
end

