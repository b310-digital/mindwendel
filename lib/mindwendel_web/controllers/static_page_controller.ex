defmodule MindwendelWeb.StaticPageController do
  use MindwendelWeb, :controller
  alias Mindwendel.Brainstormings
  alias Mindwendel.Brainstormings.Brainstorming

  plug :put_root_layout, {MindwendelWeb.Layouts, :static_page}

  def home(conn, _params) do
    current_user =
      conn
      |> Mindwendel.Services.SessionService.get_current_user_id()
      |> Mindwendel.Accounts.get_user()

    form =
      %Brainstorming{}
      |> Brainstormings.change_brainstorming(%{})
      |> Phoenix.Component.to_form()

    render(conn, "home.html",
      current_user: current_user,
      form: form
    )
  end

  def legal(conn, _params) do
    if Application.fetch_env!(:mindwendel, :options)[:feature_privacy_imprint_enabled] do
      render(conn, "legal.html")
    else
      render_404(conn)
    end
  end

  def privacy(conn, _params) do
    if Application.fetch_env!(:mindwendel, :options)[:feature_privacy_imprint_enabled] do
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
