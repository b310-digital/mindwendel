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
  end
end
