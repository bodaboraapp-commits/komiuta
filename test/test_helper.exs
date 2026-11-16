ExUnit.start()

# The production seed data migration inserts the curated Kenyan hotel catalogue.
# Tests expect a clean hotels table, so remove those seeded rows outside the
# sandbox transaction once at boot (the migration only runs when the test
# database is created).
{:ok, _apps} = Application.ensure_all_started(:xpressbus)

alias Xpressbus.Bookings.Hotel
alias Xpressbus.Repo

Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)

Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fn ->
  Repo.delete_all(Hotel)
end)
