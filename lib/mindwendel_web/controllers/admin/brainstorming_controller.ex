defmodule MindwendelWeb.Admin.BrainstormingController do
  use MindwendelWeb, :controller

  import Ecto.Query

  alias Mindwendel.Accounts
  alias Mindwendel.Brainstormings
  alias Mindwendel.CSVFormatter
  alias Mindwendel.Services.SessionService

  plug :fetch_user

  def export(conn, %{"id" => id}) do
    brainstorming =
      Brainstormings.get_brainstorming_by!(%{admin_url_id: id})
      |> Mindwendel.Repo.preload(
        lanes: {from(l in Mindwendel.Brainstormings.Lane, order_by: [asc: l.position_order]),
         ideas:
           {from(i in Mindwendel.Brainstormings.Idea,
              order_by: [asc_nulls_last: i.position_order, asc: i.inserted_at]
            ), [:link, :likes, :idea_labels, :comments, :files]}}
      )

    case get_format(conn) do
      "csv" ->
        send_download(
          conn,
          {:binary, CSVFormatter.brainstorming_to_csv(brainstorming)},
          content_type: "application/csv",
          filename: "#{brainstorming.name}.csv"
        )

      "html" ->
        conn
        |> put_layout(false)
        |> put_root_layout(false)
        |> render("export.html", brainstorming: brainstorming)
    end
  end

  def delete(conn, %{"id" => id}) do
    brainstorming = Brainstormings.get_brainstorming_by!(%{admin_url_id: id})
    Brainstormings.delete_brainstorming(brainstorming)

    conn
    |> put_flash(:info, gettext("Successfully deleted brainstorming."))
    |> put_flash(:missing_brainstorming_id, brainstorming.id)
    |> redirect(to: "/")
  end

  defp fetch_user(conn, _params) do
    current_user_id = SessionService.get_current_user_id(get_session(conn))
    current_user = Accounts.get_user(current_user_id)

    assign(conn, :current_user, current_user)
  end
end
