defmodule Mindwendel.MixProject do
  use Mix.Project

  def project do
    [
      app: :mindwendel,
      version: "0.2.9",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      # This was necessary when executing `mix test` and was thrown by priv/repo/data_migrations/migrate_idea_labels.exs .
      # The following line avoids a warning in the test, see https://elixirforum.com/t/the-inspect-protocol-has-already-been-consolidated-for-ecto-schema-with-redacted-field/34992/14
      # Apparently, it should have been resolved in the latest version of phoenix. But, we will see.
      consolidate_protocols: Mix.env() != :test,
      test_coverage: [tool: ExCoveralls]
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

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.cobertura": :test
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
      {:phoenix, "1.8.1"},
      {:phoenix_ecto, "4.6.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "1.6.1", only: :dev},
      {:phoenix_live_view, "~> 1.1.13"},
      {:esbuild, "0.10.0", runtime: Mix.env() == :dev},
      {:dart_sass, "0.7.0", runtime: Mix.env() == :dev},
      {:bypass, "2.1.0", only: :test},
      {:csv, "3.2.2"},
      {:ecto_sql, "3.13.2"},
      {:floki, "0.38.0"},
      {:gettext, "0.26.2"},
      {:httpoison, "2.2.3"},
      {:jason, "1.4.4"},
      {:oban, "2.20.1"},
      {:plug_cowboy, "2.7.4"},
      {:cowboy, "2.14.0"},
      {:postgrex, "0.21.1"},
      {:sobelow, "0.14.0", only: [:dev, :test], runtime: false},
      {:credo, "1.7.12", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18"},
      {:telemetry_metrics, "1.1.0"},
      {:telemetry_poller, "1.3.0"},
      {:timex, "3.7.13"},
      {:logger_json, "7.0.4"},
      {:libcluster, "3.5.0"},
      {:tzdata, "1.1.3"},
      {:waffle, "~> 1.1"},
      {:ex_aws, "2.5.11"},
      {:ex_aws_s3, "2.5.8"},
      {:cloak, "1.1.4"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:openai_ex, "0.9.17"},
      {:mox, "1.1.0", only: :test}
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
