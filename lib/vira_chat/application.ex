defmodule ViraChat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ViraChatWeb.Telemetry,
      ViraChat.Repo,
      {DNSCluster, query: Application.get_env(:vira_chat, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ViraChat.PubSub},
      ViraChatWeb.Presence,
      # Start to serve requests, typically the last entry
      ViraChatWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ViraChat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ViraChatWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
