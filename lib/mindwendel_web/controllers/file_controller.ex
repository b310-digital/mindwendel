defmodule MindwendelWeb.FileController do
  use MindwendelWeb, :controller

  alias Mindwendel.Attachments
  alias Mindwendel.Services.StorageService
  alias MindwendelWeb.ErrorHTML
  import Plug.Conn

  def get_file(conn, %{"id" => id}) do
    case Ecto.UUID.cast(id) do
      {:ok, _} ->
        send_attached_file(conn, id)

      :error ->
        render_404(conn)
    end
  end

  @safe_mime_types %{
    "image/jpeg" => "image/jpeg",
    "image/png" => "image/png",
    "image/gif" => "image/gif",
    "application/pdf" => "application/pdf"
  }

  defp send_attached_file(conn, attached_file_id) do
    attached_file = Attachments.get_attached_file(attached_file_id)

    case StorageService.get_file(attached_file.path) do
      {:ok, decrypted_file} ->
        conn
        |> put_resp_header("x-content-type-options", "nosniff")
        |> send_download({:binary, decrypted_file},
          filename: attached_file.name,
          content_type: safe_content_type(attached_file.file_type),
          disposition: :inline
        )

      {:error, _} ->
        render_404(conn)
    end
  end

  defp safe_content_type(file_type) do
    Map.get(@safe_mime_types, file_type, "application/octet-stream")
  end

  defp render_404(conn) do
    conn
    |> put_status(:not_found)
    |> put_view(ErrorHTML)
    |> put_layout(false)
    |> put_root_layout(false)
    |> render(:"404")
  end
end
