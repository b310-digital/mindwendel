defmodule Mindwendel.Brainstormings.Idea do
  use Mindwendel.Schema
  use Gettext, backend: MindwendelWeb.Gettext

  import Ecto.Changeset
  alias Mindwendel.Accounts.User
  alias Mindwendel.Attachments
  alias Mindwendel.Attachments.File
  alias Mindwendel.Attachments.Link
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.Comment
  alias Mindwendel.Brainstormings.IdeaIdeaLabel
  alias Mindwendel.Brainstormings.IdeaLabel
  alias Mindwendel.Brainstormings.Lane
  alias Mindwendel.Brainstormings.Like
  alias Mindwendel.FeatureFlag
  alias Mindwendel.Ideas
  alias Mindwendel.Lanes
  alias Mindwendel.UrlPreview

  @max_file_attachments 2

  schema "ideas" do
    field :body, :string, redact: true
    field :position_order, :integer
    field :username, :string, default: "Anonymous", redact: true
    field :comments_count, :integer
    has_one :link, Link
    belongs_to :user, User
    has_many :likes, Like
    has_many :comments, Comment, preload_order: [desc: :inserted_at]
    has_many :files, File
    belongs_to :brainstorming, Brainstorming
    belongs_to :lane, Lane
    many_to_many :idea_labels, IdeaLabel, join_through: IdeaIdeaLabel, on_replace: :delete

    timestamps()
  end

  @doc """
  Changeset for creating an idea. Only on creation the brainstorming of an idea is set.
  """
  def create_changeset(idea, attrs \\ %{}) do
    idea
    |> cast(attrs, [:brainstorming_id])
    |> changeset(attrs)
  end

  @doc """
  Changeset for updating an idea. The brainstorming of an existing idea cannot be changed.

  The position and the comments count are maintained internally and cannot be set
  through this changeset, see `position_changeset/2`.
  """
  def changeset(idea, attrs \\ %{}) do
    idea
    |> cast(attrs, [
      :username,
      :body,
      :lane_id,
      :user_id
    ])
    |> validate_required([:username, :body, :brainstorming_id])
    |> validate_lane_belongs_to_brainstorming()
    |> strip_html_from_body()
    |> maybe_put_idea_labels(attrs)
    |> validate_length(:body, min: 1, max: 1023)
    |> add_position_order_if_missing()
    |> validate_attachment_count(attrs)
    |> maybe_put_attachments(attrs)
  end

  @doc """
  Changeset for moving an idea to a position within a lane of its brainstorming.
  """
  def position_changeset(idea, attrs) do
    idea
    |> cast(attrs, [:lane_id, :position_order])
    |> validate_required([:lane_id, :position_order])
    |> validate_lane_belongs_to_brainstorming()
  end

  defp validate_lane_belongs_to_brainstorming(changeset) do
    lane_id = get_change(changeset, :lane_id)
    brainstorming_id = get_field(changeset, :brainstorming_id)

    if lane_id && brainstorming_id && !Lanes.lane_in_brainstorming?(lane_id, brainstorming_id) do
      add_error(
        changeset,
        :lane_id,
        dgettext_noop("errors", "The lane of this idea does not exist anymore")
      )
    else
      changeset
    end
  end

  defp strip_html_from_body(changeset) do
    case get_change(changeset, :body) do
      nil ->
        changeset

      body when is_binary(body) ->
        stripped_body = strip_html(body)
        put_change(changeset, :body, stripped_body)

      _ ->
        changeset
    end
  end

  defp strip_html(text) when is_binary(text) do
    # Convert literal newlines to <br/> so Floki natively preserves them as \n
    text
    |> String.replace("\n", "<br/>")
    |> then(fn html ->
      case Floki.parse_document(html) do
        {:ok, parsed} ->
          Floki.text(parsed, sep: " ")

        {:error, _} ->
          String.replace(html, ~r/<[^>]*>/, "")
      end
    end)
    |> normalize_whitespace()
  end

  defp strip_html(text), do: text

  defp normalize_whitespace(text) do
    text
    # Trim horizontal whitespace around newlines, then collapse remaining
    |> String.replace(~r/[^\S\n]*\n[^\S\n]*/, "\n")
    |> String.replace(~r/[^\S\n]+/, " ")
    # Cap consecutive newlines at 2 (one blank line between paragraphs)
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
  end

  defp maybe_put_idea_labels(changeset, attrs) do
    if attrs["idea_labels"] do
      put_assoc(changeset, :idea_labels, attrs["idea_labels"])
    else
      changeset
    end
  end

  defp validate_attachment_count(changeset, attrs) do
    if Ecto.assoc_loaded?(changeset.data.files) and
         length(changeset.data.files) > @max_file_attachments - 1 do
      case attrs["tmp_attachments"] == nil or Enum.empty?(attrs["tmp_attachments"]) do
        true -> changeset
        false -> add_error(changeset, :files, "too_many_files")
      end
    else
      changeset
    end
  end

  defp maybe_put_attachments(%Ecto.Changeset{data: idea} = changeset, attrs) do
    if FeatureFlag.enabled?(:feature_file_upload) and
         attrs["tmp_attachments"] != nil and Enum.empty?(changeset.errors) do
      new_files =
        Enum.map(attrs["tmp_attachments"], fn change ->
          Attachments.change_attached_file(%File{}, change)
        end)

      # Ff the idea is being updated, the old files need to be added. Otherwise these will be deleted!
      merged_files =
        if idea.id, do: new_files ++ idea.files, else: new_files

      put_assoc(changeset, :files, merged_files)
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
