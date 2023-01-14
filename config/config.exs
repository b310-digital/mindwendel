# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :mindwendel,
  ecto_repos: [Mindwendel.Repo]

# Configures the endpoint
config :mindwendel, MindwendelWeb.Endpoint,
  render_errors: [
    view: MindwendelWeb.ErrorView,
    accepts: ~w(html json),
    layout: false
  ],
  url: [
    host: "localhost",
    port: 443,
    scheme: "https"
  ],
  pubsub_server: Mindwendel.PubSub,
  live_view: [signing_salt: "MBwQ4WtK"],
  code_reloader: false

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [
    :request_id
  ]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :esbuild,
  version: "0.14.1",
  default: [
    args: ~w(
      js/app.js
      --bundle
      --target=es2016
      --outdir=../priv/static/assets
      --external:/images/*
      --loader:.woff=file
      --loader:.woff2=file
    ),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :dart_sass,
  version: "1.56.1",
  default: [
    args: ~w(
      scss/app.scss:../priv/static/assets/app.css
      scss/kits.scss:../priv/static/assets/kits.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
