defmodule MindwendelWeb.FileControllerTest do
  use MindwendelWeb.ConnCase, async: true

  alias Mindwendel.Factory
  alias Mindwendel.Services.Vault

  @file_dest "priv/static/uploads/encrypted-file-controller-test.jpg"

  describe "get_file" do
    setup do
      {:ok, encrypted_file} = Vault.encrypt("test")
      File.write(@file_dest, encrypted_file)

      on_exit(fn -> File.rm(@file_dest) end)
      :ok
    end

    test "successfully retrieves an existing file", %{conn: conn} do
      file =
        Factory.insert!(:file,
          path: "/uploads/encrypted-file-controller-test.jpg",
          name: "test.jpg"
        )

      assert get(conn, ~p"/files/#{file.id}").resp_body == "test"
    end

    test "sets x-content-type-options nosniff header", %{conn: conn} do
      file =
        Factory.insert!(:file,
          path: "/uploads/encrypted-file-controller-test.jpg",
          name: "test.jpg",
          file_type: "image/jpeg"
        )

      response = get(conn, ~p"/files/#{file.id}")
      assert get_resp_header(response, "x-content-type-options") == ["nosniff"]
    end

    test "serves allowed mime type as-is", %{conn: conn} do
      file =
        Factory.insert!(:file,
          path: "/uploads/encrypted-file-controller-test.jpg",
          name: "test.jpg",
          file_type: "image/jpeg"
        )

      response = get(conn, ~p"/files/#{file.id}")
      [content_type] = get_resp_header(response, "content-type")
      assert content_type =~ "image/jpeg"
    end

    test "serves unknown mime type as application/octet-stream", %{conn: conn} do
      file =
        Factory.insert!(:file,
          path: "/uploads/encrypted-file-controller-test.jpg",
          name: "test.svg",
          file_type: "image/svg+xml"
        )

      response = get(conn, ~p"/files/#{file.id}")
      [content_type] = get_resp_header(response, "content-type")
      assert content_type =~ "application/octet-stream"
    end

    test "returns 404 for a non-existent file", %{conn: conn} do
      non_existent_id = Ecto.UUID.generate()
      conn = get(conn, ~p"/files/#{non_existent_id}")
      assert conn.status == 404
    end

    test "returns 404 for an invalid file id", %{conn: conn} do
      conn = get(conn, ~p"/files/invalid-id")
      assert conn.status == 404
    end
  end
end
