defmodule Mindwendel.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    # The URI module in elixir does not know about the default port for the websocket protocol,
    # see https://hexdocs.pm/elixir/1.12/URI.html#default_port/1
    #
    # Therefore, we are defining the default ports here as suggested by the documentation,
    # see https://hexdocs.pm/elixir/1.12/URI.html#default_port/2
    #
    # We apply the default ports for websockets uri as described here,
    # see https://tools.ietf.org/id/draft-ietf-hybi-thewebsocketprotocol-09.html#ws_uris
    #
    # This lines were necessary to correctly construct websockets uris in this application,
    # see lib/mindwendel_web/plugs/set_response_header_content_security_policy.ex
    URI.default_port("ws", 80)
    URI.default_port("wss", 443)

    # instruct oban to use the default logger for json output:
    Oban.Telemetry.attach_default_logger()

    children = [
      # Start the Ecto repository
      Mindwendel.Repo,
      # Start the Telemetry supervisor
      MindwendelWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Mindwendel.PubSub},
      # Start the Endpoint (http/https)
      MindwendelWeb.Endpoint,
      Mindwendel.Services.Vault,
      # Start Task Supervisor for supervised async tasks
      {Task.Supervisor, name: Mindwendel.TaskSupervisor},
      # Start a worker by calling: Mindwendel.Worker.start_link(arg)
      # {Mindwendel.Worker, arg}
      {Oban, oban_config()}
    ]

    children =
      if Application.get_env(:libcluster, :topologies) do
        Logger.info("Adding Cluster.Supervisor to Supervisor tree")

        children ++
          [
            {Cluster.Supervisor,
             [Application.get_env(:libcluster, :topologies), [name: Mindwendel.ClusterSupervisor]]}
          ]
      else
        children
      end

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
