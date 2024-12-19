defmodule MindwendelWeb.StaticPageController do
  use MindwendelWeb, :controller
  alias Mindwendel.FeatureFlag

  plug :put_root_layout, {MindwendelWeb.Layouts, :static_page}

  def legal(conn, _params) do
    if FeatureFlag.enabled?(:feature_privacy_imprint_enabled) do
      render(conn, "legal.html")
    else
      render_404(conn)
    end
  end

  def privacy(conn, _params) do
    if FeatureFlag.enabled?(:feature_privacy_imprint_enabled) do
      render(conn, "privacy.html")
    else
      render_404(conn)
    end
  end

  defp render_404(conn) do
    conn
    |> put_status(:not_found)
    |> put_view(MindwendelWeb.ErrorHTML)
    |> put_layout(false)
    |> put_root_layout(false)
    |> render(:"404")
  end
end
