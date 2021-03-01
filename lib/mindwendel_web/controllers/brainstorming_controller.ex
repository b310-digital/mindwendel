defmodule MindwendelWeb.BrainstormingController do
  use MindwendelWeb, :controller
  alias Mindwendel.Brainstormings

  def create(conn, %{"brainstorming" => brainstorming_params}) do
    case Brainstormings.create_brainstorming(brainstorming_params) do
      {:ok, brainstorming} ->
        conn
        |> put_flash(
          :info,
          gettext(
            "Your brainstorming was created successfully! Share the link with other people and start brainstorming."
          )
        )
        |> redirect(to: Routes.brainstorming_show_path(conn, :show, brainstorming))

      {:error, _} ->
        conn
        |> put_flash(
          :info,
          gettext("Something went wrong when creating a brainstorming. Please try again.")
        )
        |> redirect(to: Routes.static_page_path(conn, :home))
    end
  end
end
