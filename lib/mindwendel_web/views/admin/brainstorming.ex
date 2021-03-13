defmodule MindwendelWeb.Admin.BrainstormingView do
  use MindwendelWeb, :view
  alias Mindwendel.Brainstormings

  def count_likes_for_idea(idea) do
    Brainstormings.count_likes_for_idea(idea)
  end

  def brainstorming_available_until(brainstorming) do
    Timex.shift(brainstorming.inserted_at,
      days:
        Application.fetch_env!(:mindwendel, :options)[:feature_delete_brainstormings_after_days]
    )
  end
end
