defmodule Mindwendel.Brainstormings.Idea do
  use Mindwendel.Schema

  import Ecto.Changeset
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.Like
  alias Mindwendel.Attachments.Link
  alias Mindwendel.UrlPreview

  @label_values [:red, :blue, :orange, :green, :pink]

  schema "ideas" do
    field :body, :string
    field :username, :string, default: "Anonymous"
    field :label, Ecto.Enum, values: @label_values
    has_one :link, Link
    has_many :likes, Like
    belongs_to :brainstorming, Brainstorming, foreign_key: :brainstorming_id, type: :binary_id

    timestamps()
  end

  @doc false
  def changeset(idea, attrs) do
    idea
    |> cast(attrs, [:username, :body, :brainstorming_id, :label])
    |> validate_required([:username, :body, :brainstorming_id])
    |> validate_length(:body, min: 2, max: 1023)
    |> validate_inclusion(:label, @label_values)
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
