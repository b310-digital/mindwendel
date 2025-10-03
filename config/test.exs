import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :mindwendel, Mindwendel.Repo,
  username: System.get_env("TEST_DATABASE_USER"),
  password: System.get_env("TEST_DATABASE_USER_PASSWORD"),
  database: "#{System.get_env("TEST_DATABASE_NAME")}#{System.get_env("MIX_TEST_PARTITION")}",
  hostname: System.get_env("TEST_DATABASE_HOST"),
  show_sensitive_data_on_connection_error: true,
  pool: Ecto.Adapters.SQL.Sandbox,
  # Disable parallel preloading in tests to prevent DBConnection.Ownership errors
  # Ecto spawns Tasks for parallel preloads which can outlive test processes
  max_concurrent_preloads: 0

config :mindwendel, :s3_storage_provider, Mindwendel.Services.S3ObjectStorageLocalSandboxService

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :mindwendel, MindwendelWeb.Endpoint,
  http: [
    port: 4002
  ],
  server: false,
  secret_key_base: "tYWGCQJLcTAYCJ9X9sNj022JQkTkh0ryuPO+ImBLBIFJwcfrm0+gIdryq9QTUUIM"

# Print only warnings and errors during test
config :logger, level: :warning

# See https://github.com/phoenixframework/phoenix/blob/v1.5/CHANGELOG.md#1510-2021-08-06
config :phoenix, :plug_init_mode, :runtime

config :gettext, :default_locale, "en"
config :timex, :default_locale, "en"

config :mindwendel, Oban, repo: Mindwendel.Repo, testing: :inline

# Allow private IPs for URL preview in tests
config :mindwendel, :allow_private_ips, true

# Disable AI token tracking in tests
config :mindwendel, :ai,
  enabled: false,
  token_limit_daily: nil,
  token_limit_hourly: nil,
  request_timeout: 60_000
