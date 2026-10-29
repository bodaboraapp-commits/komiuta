defmodule Xpressbus.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Xpressbus.Repo,
      XpressbusWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:xpressbus, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Xpressbus.PubSub},
      Xpressbus.Bookings.SyncServer,
      XpressbusWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Xpressbus.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    XpressbusWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
