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

  # just for migration
  embed_templates "../templates/layout/static_page*"
end
