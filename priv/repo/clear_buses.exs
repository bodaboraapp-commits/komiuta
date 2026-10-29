# Clear the buses table
alias Xpressbus.Repo
import Ecto.Query

Repo.delete_all(from(b in Xpressbus.Bookings.Bus))
IO.puts("Buses table cleared successfully")