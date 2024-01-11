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
      # Start a worker by calling: Mindwendel.Worker.start_link(arg)
      # {Mindwendel.Worker, arg}
      {Oban, oban_config()}
    ]

    # when logger_json is defined, we also want it to take care of ecto:
    if Application.get_env(:qrstorage, :logger_json) do
      :ok =
        :telemetry.attach(
          "logger-json-ecto",
          [:qrstorage, :repo, :query],
          &LoggerJSON.Ecto.telemetry_logging_handler/4,
          Logger.level()
        )
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
