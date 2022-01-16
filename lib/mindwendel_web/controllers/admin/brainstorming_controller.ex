defmodule MindwendelWeb.Admin.BrainstormingController do
  use MindwendelWeb, :controller
  alias Mindwendel.Brainstormings
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.IdeaLabel
  alias Mindwendel.CSVFormatter
  alias Mindwendel.Repo
  import Ecto.Query

  plug :fetch_user

  def create(conn, %{"brainstorming" => brainstorming_params}) do
    case Brainstormings.create_brainstorming(brainstorming_params) do
      {:ok, brainstorming} ->
        conn
        |> put_flash(
          :info,
          gettext(
            "Your brainstorming was created successfully! Please favorite or copy this link, to return later to this administrative view."
          )
        )
        |> redirect(
          to: Routes.admin_brainstorming_edit_path(conn, :edit, brainstorming.admin_url_id)
        )

      {:error, changeset} ->
        render(conn, "new.html", brainstorming: %Brainstorming{}, changeset: changeset)
    end
  end

  def export(conn, %{"id" => id}) do
    brainstorming = Brainstormings.get_brainstorming_by!(%{admin_url_id: id})
    ideas = Brainstormings.list_ideas_for_brainstorming(brainstorming.id)

    case get_format(conn) do
      "csv" ->
        send_download(
          conn,
          {:binary, CSVFormatter.ideas_to_csv(ideas)},
          content_type: "application/csv",
          filename: "#{brainstorming.name}.csv"
        )

      "html" ->
        conn |> put_layout(false) |> put_root_layout(false) |> render("export.html", ideas: ideas)
    end
  end

  def delete(conn, %{"id" => id}) do
    Brainstormings.get_brainstorming_by!(%{admin_url_id: id})
    |> Brainstormings.delete_brainstorming()

    conn
    |> put_flash(:info, gettext("Successfully deleted brainstorming."))
    |> redirect(to: "/")
  end

  defp fetch_user(conn, _params) do
    current_user_id = MindwendelService.SessionService.get_current_user_id(get_session(conn))
    current_user = Mindwendel.Accounts.get_user(current_user_id)

    assign(conn, :current_user, current_user)
  end
end
