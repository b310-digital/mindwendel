# In this file, we load production configuration and secrets
# from environment variables. You can also hardcode secrets,
# although such is generally not recommended and you have to
# remember to add this file to your .gitignore.
import Config

database_host =
  System.get_env("DATABASE_HOST") ||
    raise """
    Environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

database_name =
  System.get_env("DATABASE_NAME") ||
    raise """
    Environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

database_user =
  System.get_env("DATABASE_USER") ||
    raise """
    Environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

database_user_password =
  System.get_env("DATABASE_USER_PASSWORD") ||
    raise """
    Environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

config :mindwendel, Mindwendel.Repo,
  # ssl: true,
  host: database_host,
  username: database_user,
  password: database_user_password,
  database: database_name,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

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

# ## Using releases (Elixir v1.9+)
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start each relevant endpoint:
#
config :mindwendel, MindwendelWeb.Endpoint, server: true
#
# Then you can assemble a release by calling `mix release`.
# See `mix help release` for more information.
