# In this file, we load production configuration and secrets
# from environment variables. You can also hardcode secrets,
# although such is generally not recommended and you have to
# remember to add this file to your .gitignore.
import Config
require Logger

#
# Configuring the mindwendel endpoint
#
secret_key_base =
  System.get_env("SECRET_KEY_BASE") ||
    raise """
    Environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

url_host =
  System.get_env("URL_HOST") ||
    raise """
    Environment variable URL_HOST is missing.
    The URL_HOST should be the domain name (wihtout protocol and port) for accessing your app.
    """

config :mindwendel, MindwendelWeb.Endpoint,
  url: [host: url_host, port: 80],
  http: [
    port: String.to_integer(System.get_env("PORT") || "4000"),
    transport_options: [socket_opts: [:inet6]]
  ],
  secret_key_base: secret_key_base

config :mindwendel, :options,
  feature_brainstorming_teasers:
    Enum.member?(
      ["", "true"],
      String.trim(System.get_env("MW_FEATURE_BRAINSTORMING_TEASER") || "")
    )

#
# Configuring the mindwendel repo
#
# If the env variable `DATABASE_URL` is set,
# we will us this to configure the repo endpoint.
#
database_url = System.get_env("DATABASE_URL")

if database_url do
  Logger.info("Environment variable DATABASE_URL is defined and used for Mindwendel.Repo")
  config :mindwendel, Mindwendel.Repo, url: database_url
else
  Logger.info(
    "Environment variable DATABASE_URL is missing. Expecting DATABASE_HOST, DATABASE_NAME, DATABASE_USER, DATABASE_USER_PASSWORD to be defined"
  )

  database_host =
    System.get_env("DATABASE_HOST") ||
      raise """
      Environment variable DATABASE_HOST is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  database_name =
    System.get_env("DATABASE_NAME") ||
      raise """
      Environment variable DATABASE_NAME is missing.
      For example: mindwendel
      """

  database_user =
    System.get_env("DATABASE_USER") ||
      raise """
      Environment variable DATABASE_USER is missing.
      For example: mindwendel_user
      """

  database_user_password =
    System.get_env("DATABASE_USER_PASSWORD") ||
      raise """
      Environment variable DATABASE_USER_PASSWORD is missing.
      For example: password
      """

  config :mindwendel, Mindwendel.Repo,
    hostname: database_host,
    username: database_user,
    password: database_user_password,
    database: database_name,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
end

# ## Using releases (Elixir v1.9+)
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start each relevant endpoint:
#
config :mindwendel, MindwendelWeb.Endpoint, server: true
#
# Then you can assemble a release by calling `mix release`.
# See `mix help release` for more information.
