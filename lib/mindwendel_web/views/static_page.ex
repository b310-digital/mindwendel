defmodule MindwendelWeb.StaticPageView do
  use MindwendelWeb, :view
  alias Mindwendel.Brainstormings

  def list_brainstormings_for(user) do
    Brainstormings.list_brainstormings_for(user.id)
  end
end
