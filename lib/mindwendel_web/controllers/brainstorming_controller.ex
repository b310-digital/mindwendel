defmodule MindwendelWeb.BrainstormingController do
  use MindwendelWeb, :controller
  alias Mindwendel.Brainstormings
  alias Mindwendel.Accounts

  def create(conn, %{"brainstorming" => brainstorming_params}) do
    current_user =
      MindwendelService.SessionService.get_current_user_id(conn)
      |> Accounts.get_or_create_user()

    with {:ok, brainstorming} <- Brainstormings.create_brainstorming(brainstorming_params),
         {:ok, _brainstorming_moderating_user} <-
           Brainstormings.add_moderating_user(brainstorming, current_user) do
      conn
      |> put_flash(
        :info,
        gettext(
          "Your brainstorming was created successfully! Share the link with other people and start brainstorming."
        )
      )
      |> redirect(to: Routes.brainstorming_show_path(conn, :show, brainstorming))
    else
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
