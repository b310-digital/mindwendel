defmodule MindwendelWeb.Admin.BrainstormingView do
  use MindwendelWeb, :view
  alias Mindwendel.Brainstormings

  def count_likes_for_idea(idea) do
    Brainstormings.count_likes_for_idea(idea)
  end
end
