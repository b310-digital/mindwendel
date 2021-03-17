defmodule Mindwendel.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Mindwendel.Repo,
      # Start the Telemetry supervisor
      MindwendelWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Mindwendel.PubSub},
      # Start the Endpoint (http/https)
      MindwendelWeb.Endpoint,
      # Start a worker by calling: Mindwendel.Worker.start_link(arg)
      # {Mindwendel.Worker, arg}
      {Oban, oban_config()}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Mindwendel.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    MindwendelWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp oban_config do
    Application.get_env(:mindwendel, Oban)
  end
end
