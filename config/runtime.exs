# In this file, we load production configuration and secrets
# from environment variables. You can also hardcode secrets,
# although such is generally not recommended and you have to
# remember to add this file to your .gitignore.
import Config
require Logger

if config_env() == :prod do
  # configure logging:
  config :logger_json, :backend,
    metadata: [:request_id],
    json_encoder: Jason,
    formatter: LoggerJSON.Formatters.BasicLogger

  # override Elixir's Logger with logger_json:
  config :logger, backends: [LoggerJSON]
end

if config_env() != :test do
  unless System.get_env("DATABASE_HOST") do
    Logger.warning(
      "Environment variable DATABASE_HOST is missing, e.g. DATABASE_HOST=localhost or DATABASE_HOST=postgres"
    )
  end

  unless System.get_env("DATABASE_NAME") do
    Logger.warning("Environment variable DATABASE_NAME is missing, e.g. DATABASE_NAME=mindwendel")
  end

  unless System.get_env("DATABASE_USER") do
    Logger.warning(
      "Environment variable DATABASE_USER is missing, e.g. DATABASE_USER=mindwendel_user"
    )
  end

  unless System.get_env("DATABASE_USER_PASSWORD") do
    Logger.warning(
      "Environment variable DATABASE_USER_PASSWORD is missing, e.g. DATABASE_USER_PASSWORD=mindwendel_user_password"
    )
  end

  # disable on prod, because logger_json will take care of this. set to :debug for test and dev
  ecto_log_level = if config_env() == :prod, do: false, else: :debug

  config :mindwendel, Mindwendel.Repo,
    database: System.get_env("DATABASE_NAME"),
    hostname: System.get_env("DATABASE_HOST"),
    password: System.get_env("DATABASE_USER_PASSWORD"),
    username: System.get_env("DATABASE_USER"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10")),
    port: String.to_integer(System.get_env("DATABASE_PORT", "5432")),
    url: System.get_env("DATABASE_URL"),
    timeout: String.to_integer(System.get_env("DATABASE_TIMEOUT", "15000")),
    log: ecto_log_level,
    ssl: System.get_env("DATABASE_SSL", "true") == "true",
    ssl_opts: [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      server_name_indication: String.to_charlist(System.get_env("DATABASE_HOST")),
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ]

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      Environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  url_host =
    System.get_env("URL_HOST") ||
      System.get_env("HOST") ||
      raise """
      Environment variable URL_HOST is missing.
      The URL_HOST should be the domain name (wihtout protocol and port) for accessing your app.
      """

  config :mindwendel, MindwendelWeb.Endpoint,
    url: [
      host: url_host,
      port:
        String.to_integer(
          System.get_env("MW_ENDPOINT_URL_PORT") ||
            System.get_env("URL_PORT") ||
            "443"
        ),
      scheme:
        System.get_env("MW_ENDPOINT_URL_SCHEME") ||
          System.get_env("URL_SCHEME") ||
          "https"
    ],
    http: [
      port:
        String.to_integer(
          System.get_env("MW_ENDPOINT_HTTP_PORT") ||
            System.get_env("PORT") ||
            "4000"
        )
    ],
    secret_key_base: secret_key_base

  # ## Using releases (Elixir v1.9+)
  #
  # If you are doing OTP releases, you need to instruct Phoenix
  # to start each relevant endpoint:
  #
  if config_env() == :prod do
    config :mindwendel, MindwendelWeb.Endpoint, server: true

    # Enable libcluster if set:
    if System.get_env("MW_ENABLE_LIBCLUSTER") == "true" do
      Logger.info("Configuring libcluster to use Kubernetes.DNS strategy")

      config :libcluster,
        topologies: [
          k8s_mindwendel: [
            strategy: Elixir.Cluster.Strategy.Kubernetes.DNS,
            config: [
              service: "mindwendel-cluster",
              application_name: "mindwendel"
            ]
          ]
        ]
    end
  end

  #
  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.
end

# force en in test:
default_locale =
  case config_env() do
    :test -> "en"
    _ -> String.trim(System.get_env("MW_DEFAULT_LOCALE") || "en")
  end

config :gettext, :default_locale, default_locale
config :timex, :default_locale, default_locale

parsed_feature_brainstorming_removal_after_days =
  String.trim(System.get_env("MW_FEATURE_BRAINSTORMING_REMOVAL_AFTER_DAYS") || "")

delete_brainstormings_after_days =
  if parsed_feature_brainstorming_removal_after_days != "" do
    String.to_integer(parsed_feature_brainstorming_removal_after_days)
  else
    30
  end

# enable/disable brainstorming teasers and configure delete brainstormings option:
config :mindwendel, :options,
  feature_brainstorming_teasers:
    Enum.member?(
      ["", "true"],
      String.trim(System.get_env("MW_FEATURE_BRAINSTORMING_TEASER") || "")
    ),
  feature_brainstorming_removal_after_days: delete_brainstormings_after_days,
  # use a strict csp everywhere except in development. we need to relax the setting a bit for webpack
  csp_relax: config_env() == :dev

if config_env() == :prod || config_env() == :dev do
  config :mindwendel, Oban,
    repo: Mindwendel.Repo,
    plugins: [
      {Oban.Plugins.Cron,
       crontab: [
         {System.get_env("MW_FEATURE_BRAINSTORMING_REMOVAL_CRON", "@midnight"),
          Mindwendel.Worker.RemoveBrainstormingsAndUsersAfterPeriodWorker}
       ]}
    ],
    queues: [default: 1]
end
