defmodule Mindwendel.Repo.Migrations.CreateAiTokenUsage do
  use Ecto.Migration

  def change do
    create table(:ai_token_usage, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :period_type, :string, null: false
      add :period_start, :utc_datetime_usec, null: false
      add :input_tokens, :bigint, null: false, default: 0
      add :output_tokens, :bigint, null: false, default: 0
      add :total_tokens, :bigint, null: false, default: 0
      add :request_count, :integer, null: false, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:ai_token_usage, [:period_type, :period_start])
    create index(:ai_token_usage, [:period_start])
  end
end
