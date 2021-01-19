defmodule Mindwendel.Repo do
  use Ecto.Repo,
    otp_app: :mindwendel,
    adapter: Ecto.Adapters.Postgres
end
