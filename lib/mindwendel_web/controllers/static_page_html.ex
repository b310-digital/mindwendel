defmodule MindwendelWeb.StaticPageHTML do
  use MindwendelWeb, :html
  alias Mindwendel.Brainstormings

  embed_templates "static_page_html/*"

  def list_brainstormings_for(user) do
    Brainstormings.list_brainstormings_for(user.id)
  end

  def brainstormings_available_until() do
    Timex.Duration.from_days(
      Application.fetch_env!(:mindwendel, :options)[:feature_brainstorming_removal_after_days]
    )
    |> Timex.format_duration(:humanized)
  end
end
