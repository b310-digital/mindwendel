defmodule Mindwendel.Brainstormings.StorageServiceTest do
  use Mindwendel.DataCase, async: true

  alias Mindwendel.Services.StorageService

  describe "#store_file" do
    test "successfully stores a file" do
      StorageService.store_file("mindwendel-test.png", "test/fixtures/mindwendel-test.png", "png")
      target_path = "priv/static/uploads/encrypted-mindwendel-test.png"
      assert File.exists?(target_path)

      # cleanup
      File.rm(target_path)
    end
  end

  describe "#delete_file" do
    test "successfully removes a file" do
      StorageService.store_file(
        "mindwendel-removal-test.png",
        "test/fixtures/mindwendel-test.png",
        "png"
      )

      target_path = "priv/static/uploads/encrypted-mindwendel-removal-test.png"
      StorageService.delete_file("uploads/encrypted-mindwendel-removal-test.png")

      refute File.exists?(target_path)
    end
  end

  describe "#get_file" do
    test "successfully stores a file" do
      StorageService.store_file(
        "mindwendel-get-test.png",
        "test/fixtures/mindwendel-test.png",
        "png"
      )

      target_path = "priv/static/uploads/encrypted-mindwendel-get-test.png"

      {status, _file_content} =
        StorageService.get_file("uploads/encrypted-mindwendel-get-test.png")

      assert status == :ok

      # cleanup
      File.rm(target_path)
    end
  end
end
