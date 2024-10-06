defmodule MindwendelWeb.StaticPageController do
  use MindwendelWeb, :controller
  alias Mindwendel.Brainstormings
  alias Mindwendel.Brainstormings.Brainstorming

  plug :put_root_layout, {MindwendelWeb.Layouts, :kits_static_page}

  def home(conn, _params) do
    current_user =
      conn
      |> Mindwendel.Services.SessionService.get_current_user_id()
      |> Mindwendel.Accounts.get_user()

    form =
      %Brainstorming{}
      |> Brainstormings.change_brainstorming(%{})
      |> Phoenix.Component.to_form()

    render(conn |> put_layout(false), "kits_home.html",
      current_user: current_user,
      form: form
    )
  end
end
