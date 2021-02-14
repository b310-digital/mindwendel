defmodule MindwendelWeb.LayoutView do
  use MindwendelWeb, :view
  alias Mindwendel.Brainstormings

  def list_brainstormings_for(user, limit \\ 3) do
    Brainstormings.list_brainstormings_for(user.id, limit)
  end
end
