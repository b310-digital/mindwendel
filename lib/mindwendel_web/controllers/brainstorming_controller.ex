defmodule MindwendelWeb.BrainstormingController do
  use MindwendelWeb, :controller
  alias Mindwendel.Brainstormings
  alias Mindwendel.Accounts

  def create(conn, %{"brainstorming" => brainstorming_params}) do
    current_user =
      MindwendelService.SessionService.get_current_user_id(conn)
      |> Accounts.get_or_create_user()

    case Brainstormings.create_brainstorming(current_user, brainstorming_params) do
      {:ok, brainstorming} ->
        conn
        |> put_flash(
          :info,
          gettext(
            "Your brainstorming was created successfully! Share the link with other people and start brainstorming."
          )
        )
        |> redirect(to: Routes.brainstorming_show_path(conn, :show, brainstorming))

      {:error, changeset} ->
        conn
        |> put_flash(
          :error,
          gettext("Something went wrong when creating a brainstorming. Please try again.")
        )
        |> redirect(to: Routes.static_page_path(conn, :home))
    end
  end
end
