defmodule MindwendelWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use MindwendelWeb, :controller` and
  `use MindwendelWeb, :live_view`.
  """
  use MindwendelWeb, :html

  embed_templates "../templates/layout/*"

  alias Mindwendel.Brainstormings

  def list_brainstormings_for(user, limit \\ 3) do
    Brainstormings.list_brainstormings_for(user.id, limit)
  end

  def admin_view(current_view) do
    current_view == MindwendelWeb.Admin.BrainstormingLive.Edit
  end
end
