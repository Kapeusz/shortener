defmodule Shortnr.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ShortnrWeb.Telemetry,
      Shortnr.Repo,
      {DNSCluster, query: Application.get_env(:shortnr, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Shortnr.PubSub},
      # Per-node ETS cache for long_url -> slug
      Shortnr.UrlCache,
      # Redirect metrics collector (PubSub -> Postgres batch inserts)
      Shortnr.Metrics.Collector,
      # Start the Finch HTTP client for sending emails
      {Finch, name: Shortnr.Finch},
      # Start a worker by calling: Shortnr.Worker.start_link(arg)
      # {Shortnr.Worker, arg},
      # Start to serve requests, typically the last entry
      ShortnrWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Shortnr.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ShortnrWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
