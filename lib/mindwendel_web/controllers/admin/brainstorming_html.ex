defmodule MindwendelWeb.Admin.BrainstormingHTML do
  use MindwendelWeb, :html
  alias Mindwendel.Likes

  embed_templates "brainstorming_html/*"

  def lane_name(lane) do
    lane.name || gettext("Untitled")
  end

  def format_datetime(nil), do: ""

  def format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end

  def safe_url(nil), do: "#"

  def safe_url(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme} when scheme in ["http", "https"] -> url
      _ -> "#"
    end
  end

  def safe_url(_), do: "#"
end
