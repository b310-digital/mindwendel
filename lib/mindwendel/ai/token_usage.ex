defmodule Mindwendel.AI.TokenUsage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "ai_token_usage" do
    field :period_type, :string
    field :period_start, :utc_datetime_usec
    field :input_tokens, :integer, default: 0
    field :output_tokens, :integer, default: 0
    field :total_tokens, :integer, default: 0
    field :request_count, :integer, default: 0

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(token_usage, attrs) do
    token_usage
    |> cast(attrs, [
      :period_type,
      :period_start,
      :input_tokens,
      :output_tokens,
      :total_tokens,
      :request_count
    ])
    |> validate_required([:period_type, :period_start])
    |> validate_inclusion(:period_type, ["hourly", "daily"])
    |> unique_constraint([:period_type, :period_start])
  end
end
