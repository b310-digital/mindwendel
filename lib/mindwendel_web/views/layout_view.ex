defmodule MindwendelWeb.LayoutView do
  use MindwendelWeb, :view
  alias Mindwendel.Brainstormings

  def list_brainstormings_for(user, limit \\ 3) do
    Brainstormings.list_brainstormings_for(user.id, limit)
  end

  def admin_route(conn) do
    route_scope = conn.request_path |> String.split("/", trim: true) |> List.first()
    route_scope == "admin"
  end
end
