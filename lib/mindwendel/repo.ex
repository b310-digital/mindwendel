defmodule Mindwendel.Repo do
  use Ecto.Repo,
    otp_app: :mindwendel,
    adapter: Ecto.Adapters.Postgres

  def count(query) do
    aggregate(query, :count)
  end
end
