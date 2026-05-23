defmodule Mindwendel.CSVFormatter do
  alias Mindwendel.Likes

  def brainstorming_to_csv(brainstorming) do
    base_url = MindwendelWeb.Endpoint.url()

    [["lane", "idea", "username", "likes", "labels", "comments", "files", "link_url"]]
    |> Stream.concat(
      brainstorming.lanes
      |> Stream.flat_map(fn lane ->
        lane.ideas
        |> Enum.map(fn idea ->
          [
            sanitize_csv_cell(lane.name || ""),
            sanitize_csv_cell(idea.body),
            sanitize_csv_cell(Gettext.gettext(MindwendelWeb.Gettext, idea.username)),
            Likes.count_likes_for_idea(idea),
            sanitize_csv_cell(format_labels(idea.idea_labels)),
            sanitize_csv_cell(format_comments(idea.comments)),
            sanitize_csv_cell(format_files(idea.files, base_url)),
            sanitize_csv_cell(format_link(idea.link))
          ]
        end)
      end)
    )
    |> CSV.encode()
    |> Enum.to_list()
  end

  defp format_labels(labels) do
    Enum.map_join(labels, "; ", &sanitize_csv_cell(&1.name))
  end

  defp format_comments(comments) do
    Enum.map_join(comments, " | ", fn c ->
      username = sanitize_csv_cell(Gettext.gettext(MindwendelWeb.Gettext, c.username))
      body = sanitize_csv_cell(c.body)
      "#{username}: #{body}"
    end)
  end

  defp format_files(files, base_url) do
    Enum.map_join(files, "; ", &"#{base_url}/files/#{&1.id}")
  end

  defp format_link(nil), do: ""

  defp format_link(link) do
    url = link.url || ""

    case URI.parse(url) do
      %URI{scheme: scheme} when scheme in ["http", "https"] -> url
      _ -> ""
    end
  end

  defp sanitize_csv_cell(value) when is_binary(value) do
    if String.match?(value, ~r/^[=\+\-\|@\t\r\n]/) do
      "'" <> value
    else
      value
    end
  end

  defp sanitize_csv_cell(_), do: ""
end
