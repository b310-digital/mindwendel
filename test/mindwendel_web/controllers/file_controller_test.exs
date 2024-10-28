defmodule MindwendelWeb.FileControllerTest do
  use MindwendelWeb.ConnCase
  alias Mindwendel.Services.Vault
  alias Mindwendel.Factory

  @file_dest "priv/static/uploads/encrypted-test.jpg"

  describe "get_file" do
    setup do
      upload_path = "priv/static/uploads/"
      File.mkdir_p!(Path.dirname(upload_path))

      {:ok, encrypted_file} = Vault.encrypt("test")
      File.write(@file_dest, encrypted_file)

      on_exit(fn -> File.rm(@file_dest) end)
      :ok
    end

    test "successfully retrieves an existing file", %{conn: conn} do
      file = Factory.insert!(:file, path: "/uploads/encrypted-test.jpg", name: "test.jpg")

      assert get(conn, ~p"/files/#{file.id}").resp_body == "test"
    end
  end
end
