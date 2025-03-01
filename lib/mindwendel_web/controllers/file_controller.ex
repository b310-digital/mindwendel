defmodule MindwendelWeb.FileController do
  use MindwendelWeb, :controller
  alias Mindwendel.Attachments
  import Plug.Conn

  def get_file(conn, %{"id" => id}) do
    case Ecto.UUID.cast(id) do
      {:ok, _} ->
        send_attached_file(conn, id)

      :error ->
        render_404(conn)
    end
  end

  defp send_attached_file(conn, attached_file_id) do
    attached_file = Attachments.get_attached_file(attached_file_id)

    case Mindwendel.Services.StorageService.get_file(attached_file.path) do
      {:ok, decrypted_file} ->
        send_download(conn, {:binary, decrypted_file},
          filename: attached_file.name,
          content_type: attached_file.file_type,
          disposition: :inline
        )

      {:error, _} ->
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
