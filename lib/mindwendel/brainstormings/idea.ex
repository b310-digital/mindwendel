defmodule Mindwendel.Brainstormings.Idea do
  use Mindwendel.Schema

  import Ecto.Changeset
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.IdeaLabel
  alias Mindwendel.Brainstormings.IdeaIdeaLabel
  alias Mindwendel.Brainstormings.Like
  alias Mindwendel.Brainstormings.Lane
  alias Mindwendel.Brainstormings.Attachment
  alias Mindwendel.Ideas
  alias Mindwendel.Attachments
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
    has_many :attachments, Attachment
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
    |> maybe_put_attachments(idea, attrs)
    |> validate_length(:body, min: 1, max: 1023)
    |> validate_inclusion(:deprecated_label, @label_values)
    |> add_position_order_if_missing()
  end

  defp maybe_put_idea_labels(changeset, attrs) do
    if attrs["idea_labels"] do
      put_assoc(changeset, :idea_labels, attrs["idea_labels"])
    else
      changeset
    end
  end

  # Only called on first create, the parameter 'attachments' is not used for updates and handled seperately.
  defp maybe_put_attachments(changeset, idea, attrs) do
    if attrs["attachments"] do
      IO.inspect(idea)
      put_assoc(changeset, :attachments, idea.attachments)
      cast_assoc(changeset, :attachments, with: &Attachment.changeset/2)
    else
      changeset
    end
  end

  defp add_position_order_if_missing(
         %Ecto.Changeset{
           changes:
             %{
               lane_id: lane_id,
               brainstorming_id: brainstorming_id
             } = changes
         } = changeset
       )
       when not is_map_key(changes, :position_order) do
    changeset
    |> put_change(:position_order, generate_position_order(brainstorming_id, lane_id))
  end

  defp add_position_order_if_missing(changeset) do
    changeset
  end

  def build_link(idea) do
    idea |> check_for_link_in_body
  end

  defp generate_position_order(brainstorming_id, lane_id) do
    max = Ideas.get_max_position_order(brainstorming_id, %{lane_id: lane_id})
    if max, do: max + 1, else: 1
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
