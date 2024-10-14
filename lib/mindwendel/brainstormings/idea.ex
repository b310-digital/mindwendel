defmodule Mindwendel.Brainstormings.Idea do
  use Mindwendel.Schema

  import Ecto.Changeset
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.IdeaLabel
  alias Mindwendel.Brainstormings.IdeaIdeaLabel
  alias Mindwendel.Brainstormings.Like
  alias Mindwendel.Brainstormings.Lane
  alias Mindwendel.Attachments.Link
  alias Mindwendel.UrlPreview
  alias Mindwendel.Accounts.User

  @label_values [:label_1, :label_2, :label_3, :label_4, :label_5]

  schema "ideas" do
    field :body, :string
    field :position_order, :integer
    field :username, :string, default: "Anonymous"
    field :deprecated_label, Ecto.Enum, source: :label, values: @label_values
    has_one :link, Link
    belongs_to :user, User
    has_many :likes, Like
    belongs_to :brainstorming, Brainstorming
    belongs_to :label, IdeaLabel, on_replace: :nilify
    belongs_to :lane, Lane
    many_to_many :idea_labels, IdeaLabel, join_through: IdeaIdeaLabel, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(idea, attrs \\ %{}) do
    idea
    |> cast(attrs, [
      :username,
      :body,
      :brainstorming_id,
      :lane_id,
      :deprecated_label,
      :label_id,
      :user_id,
      :position_order
    ])
    |> validate_required([:username, :body, :brainstorming_id])
    |> maybe_put_idea_labels(attrs)
    |> validate_length(:body, min: 1, max: 1023)
    |> validate_inclusion(:deprecated_label, @label_values)
  end

  defp maybe_put_idea_labels(changeset, attrs) do
    if attrs["idea_labels"] do
      put_assoc(changeset, :idea_labels, attrs["idea_labels"])
    else
      changeset
    end
  end

  def build_link(idea) do
    idea |> check_for_link_in_body
  end

  defp check_for_link_in_body(idea) do
    change = changeset(idea, %{})
    body = get_field(change, :body)
    matched_url = if body, do: UrlPreview.extract_url(body), else: ""

    if matched_url != "" do
      {status, title: title, description: description, img_preview_url: img_preview_url} =
        UrlPreview.fetch_url(matched_url)

      if status == :ok,
        do:
          put_assoc(change, :link, %Link{
            url: matched_url,
            title: title,
            description: description,
            img_preview_url: img_preview_url
          }),
        else: change
    else
      change
    end
  end
end
