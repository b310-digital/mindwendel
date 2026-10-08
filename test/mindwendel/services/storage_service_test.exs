defmodule Mindwendel.Brainstormings.StorageServiceTest do
  use Mindwendel.DataCase, async: true

  import ExUnit.CaptureLog

  alias Mindwendel.Services.StorageService

  defmodule FailingS3Client do
    def put_object(_bucket, _path, _file, _opts), do: {:error, :econnrefused}
    def get_object(_bucket, _path), do: {:error, {:http_error, 503, "unavailable"}}
    def delete_object(_bucket, _path), do: {:error, :timeout}
  end

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

  describe "storage errors" do
    @describetag capture_log: true

    test "store_file returns an error when the storage is unreachable" do
      assert {:error, "Issue while storing file."} =
               StorageService.store_file(
                 "mindwendel-test.png",
                 "test/fixtures/mindwendel-test.png",
                 "png",
                 FailingS3Client
               )
    end

    test "get_file returns an error on a server error without logging the response" do
      log =
        capture_log(fn ->
          assert {:error, "Issue while loading file."} =
                   StorageService.get_file("uploads/any.png", FailingS3Client)
        end)

      assert log =~ "HTTP 503"
      refute log =~ "unavailable"
    end

    test "store_file logs the type of typed storage errors" do
      defmodule ThrottledS3Client do
        def put_object(_bucket, _path, _file, _opts),
          do: {:error, {"ThrottlingException", "Rate exceeded for key uploads/secret.png"}}
      end

      log =
        capture_log(fn ->
          assert {:error, "Issue while storing file."} =
                   StorageService.store_file(
                     "mindwendel-test.png",
                     "test/fixtures/mindwendel-test.png",
                     "png",
                     ThrottledS3Client
                   )
        end)

      assert log =~ "ThrottlingException"
      refute log =~ "Rate exceeded"
    end

    test "delete_file returns an error on a timeout" do
      assert {:error, "Files not deleted"} =
               StorageService.delete_file("uploads/any.png", FailingS3Client)
    end
  end
end
