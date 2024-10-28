defmodule Mindwendel.Brainstormings.StorageServiceTest do
  use Mindwendel.DataCase
  alias Mindwendel.Services.StorageService

  describe "#store_file" do
    test "successfully stores a file" do
      StorageService.store_file("mindwendel-test.jpg", "test/fixtures/mindwendel-test.jpg", "jpg")
      target_path = "priv/static/uploads/encrypted-mindwendel-test.jpg"
      assert File.exists?(target_path)

      # cleanup
      File.rm(target_path)
    end
  end

  describe "#delete_file" do
    test "successfully removes a file" do
      StorageService.store_file(
        "mindwendel-removal-test.jpg",
        "test/fixtures/mindwendel-test.jpg",
        "jpg"
      )

      target_path = "priv/static/uploads/encrypted-mindwendel-removal-test.jpg"
      StorageService.delete_file("uploads/encrypted-mindwendel-removal-test.jpg")

      refute File.exists?(target_path)
    end
  end

  describe "#get_file" do
    test "successfully stores a file" do
      StorageService.store_file(
        "mindwendel-get-test.jpg",
        "test/fixtures/mindwendel-test.jpg",
        "jpg"
      )

      target_path = "priv/static/uploads/encrypted-mindwendel-get-test.jpg"

      {status, _file_content} =
        StorageService.get_file("uploads/encrypted-mindwendel-get-test.jpg")

      assert status === :ok

      # cleanup
      File.rm(target_path)
    end
  end
end
