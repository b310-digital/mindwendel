defmodule MindwendelWeb.Admin.BrainstormingView do
  use MindwendelWeb, :view
  alias Mindwendel.Likes

  def count_likes_for_idea(idea) do
    Likes.count_likes_for_idea(idea)
  end

  def brainstorming_available_until(brainstorming) do
    Timex.shift(brainstorming.last_accessed_at,
      days:
        Application.fetch_env!(:mindwendel, :options)[:feature_brainstorming_removal_after_days]
    )
  end
end
