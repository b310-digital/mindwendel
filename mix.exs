defmodule Mindwendel.MixProject do
  use Mix.Project

  def project do
    [
      app: :mindwendel,
      version: "0.1.0",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      # This was necessary when executing `mix test` and was thrown by priv/repo/data_migrations/migrate_idea_labels.exs .
      # The following line avoids a warning in the test, see https://elixirforum.com/t/the-inspect-protocol-has-already-been-consolidated-for-ecto-schema-with-redacted-field/34992/14
      # Apparently, it should have been resolved in the latest version of phoenix. But, we will see.
      consolidate_protocols: Mix.env() != :test
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Mindwendel.Application, []},
      extra_applications: [
        :logger,
        :runtime_tools
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "1.6.16"},
      {:phoenix_ecto, "4.4.3"},
      {:phoenix_html, "3.3.3"},
      {:phoenix_live_dashboard, "0.7.2"},
      {:phoenix_live_reload, "1.4.1", only: :dev},
      {:phoenix_live_view, "0.18.3"},
      {:esbuild, "0.5.0", runtime: Mix.env() == :dev},
      {:dart_sass, "0.5.1", runtime: Mix.env() == :dev},
      {:bypass, "2.1.0", only: :test},
      {:csv, "3.2.1"},
      {:ecto_sql, "3.11.1"},
      {:floki, "0.35.2"},
      {:gettext, "0.24.0"},
      {:httpoison, "2.2.1"},
      {:jason, "1.4.1"},
      {:oban, "2.17.1"},
      {:plug_cowboy, "2.6.1"},
      {:postgrex, "0.17.4"},
      {:sobelow, "0.13.0", only: :dev},
      {:telemetry_metrics, "0.6.1"},
      {:telemetry_poller, "1.0.0"},
      {:timex, "3.7.11"},
      {:logger_json, "5.1.2"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.test.prepare": ["cmd MIX_ENV=test mix ecto.reset"],
      setup: ["deps.get", "ecto.setup", "cmd npm install --prefix assets"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.deploy": [
        # run sass first, since we'll compile our scss files to css, and include this in esbuild:
        "sass default --no-source-map --style=compressed",
        "esbuild default --minify",
        "phx.digest"
      ]
    ]
  end
end
