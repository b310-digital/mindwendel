defmodule MindwendelWeb.Admin.BrainstormingController do
  use MindwendelWeb, :controller
  alias Mindwendel.Brainstormings
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.CSVFormatter

  def edit(conn, %{"id" => id}) do
    brainstorming = Brainstormings.get_brainstorming_by!(%{admin_url_id: id})

    render(conn, "edit.html",
      brainstorming: brainstorming,
      changeset: Brainstormings.change_brainstorming(brainstorming, %{}),
      uri: current_url(conn)
    )
  end

  def create(conn, %{"brainstorming" => brainstorming_params}) do
    case Brainstormings.create_brainstorming(brainstorming_params) do
      {:ok, brainstorming} ->
        conn
        |> put_flash(
          :info,
          "Your brainstorming was created successfully! Please favorite or copy this link, to return later to this administrative view."
        )
        |> redirect(to: Routes.admin_brainstorming_path(conn, :edit, brainstorming.admin_url_id))

      {:error, changeset} ->
        render(conn, "new.html", brainstorming: %Brainstorming{}, changeset: changeset)
    end
  end

  def update(conn, %{"id" => id, "brainstorming" => brainstorming_params}) do
    brainstorming = Brainstormings.get_brainstorming_by!(%{admin_url_id: id})

    case Brainstormings.update_brainstorming(brainstorming, brainstorming_params) do
      {:ok, brainstorming} ->
        redirect(conn,
          to: Routes.admin_brainstorming_path(conn, :edit, brainstorming.admin_url_id)
        )

      {:error, changeset} ->
        render(conn, "edit.html", brainstorming: brainstorming, changeset: changeset)
    end
  end

  def export(conn, %{"id" => id}) do
    brainstorming = Brainstormings.get_brainstorming_by!(%{admin_url_id: id})

    send_download(
      conn,
      {:binary, export_brainstorming(brainstorming.id)},
      content_type: "application/csv",
      filename: "#{brainstorming.name}.csv"
    )
  end

  def delete(conn, %{"id" => id}) do
    Brainstormings.get_brainstorming_by!(%{admin_url_id: id})
    |> Brainstormings.delete_brainstorming()

    conn
    |> put_flash(:info, "Successfully deleted brainstorming.")
    |> redirect(to: "/")
  end

  defp export_brainstorming(id) do
    id
    |> Brainstormings.list_ideas_for_brainstorming()
    |> CSVFormatter.ideas_to_csv()
  end
end
