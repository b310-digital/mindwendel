defmodule Mindwendel.Brainstormings.Idea do
  use Mindwendel.Schema

  import Ecto.Changeset
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.IdeaLabel
  alias Mindwendel.Brainstormings.IdeaIdeaLabel
  alias Mindwendel.Brainstormings.Like
  alias Mindwendel.Brainstormings.Lane
  alias Mindwendel.Brainstormings.Comment
  alias Mindwendel.FeatureFlag
  alias Mindwendel.Ideas
  alias Mindwendel.Attachments
  alias Mindwendel.Attachments.Link
  alias Mindwendel.Attachments.File
  alias Mindwendel.UrlPreview
  alias Mindwendel.Accounts.User

  @max_file_attachments 2

  schema "ideas" do
    field :body, :string
    field :position_order, :integer
    field :username, :string, default: "Anonymous"
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

  @doc false
  def changeset(idea, attrs \\ %{}) do
    idea
    |> cast(attrs, [
      :username,
      :body,
      :brainstorming_id,
      :lane_id,
      :user_id,
      :position_order,
      :comments_count
    ])
    |> validate_required([:username, :body, :brainstorming_id])
    |> strip_html_from_body()
    |> maybe_put_idea_labels(attrs)
    |> validate_length(:body, min: 1, max: 1023)
    |> add_position_order_if_missing()
    |> validate_attachment_count(attrs)
    |> maybe_put_attachments(idea, attrs)
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
    # Strip all HTML tags by parsing with Floki and extracting text content
    # This removes all tags, event handlers, and JavaScript
    case Floki.parse_document(text) do
      {:ok, parsed} ->
        parsed
        |> Floki.text(sep: " ")
        |> normalize_whitespace()

      {:error, _} ->
        # If parsing fails, fall back to basic regex stripping
        text
        |> String.replace(~r/<[^>]*>/, "")
        |> normalize_whitespace()
    end
  end

  defp strip_html(text), do: text

  defp normalize_whitespace(text) do
    text
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
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

  defp maybe_put_attachments(changeset, idea, attrs) do
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
