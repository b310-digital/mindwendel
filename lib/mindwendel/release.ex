# https://hexdocs.pm/phoenix/releases.html
defmodule Mindwendel.Release do
  @moduledoc false

  @app :mindwendel

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def run_seeds do
    Code.eval_file("#{:code.priv_dir(@app)}/repo/seeds.exs")
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # This ensures that the ssl module is also started.
    # This is necessary to establish an ssl connection ot the database.
    # See https://elixirforum.com/t/ssl-connection-cannot-be-established-using-elixir-releases/25444/9
    Application.ensure_all_started(:ssl)

    Application.load(@app)
  end
end
