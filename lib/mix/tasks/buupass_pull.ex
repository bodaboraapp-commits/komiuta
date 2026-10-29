defmodule Mix.Tasks.Buupass.Pull do
  use Mix.Task

  @shortdoc "Pulls all common route data from BuuPass into the local database"

  def run(_) do
    # Start the application and its dependencies (like Repo)
    Mix.Task.run("app.start")

    Xpressbus.Bookings.Seeder.run()
  end
end
