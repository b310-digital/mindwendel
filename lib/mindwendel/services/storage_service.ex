defmodule Mindwendel.Services.StorageService do
  alias Mindwendel.Services.S3ObjectStorageService
  alias Mindwendel.Services.Vault
  require Logger

  defp get_file(filename, type) do
    case S3ObjectStorageService.get_object(bucket_name(), bucket_path(filename, type)) do
      {:ok, response} ->
        case response.status_code do
          200 ->
            case Vault.decrypt(response.body) do
              {:ok, decrypted_file} ->
                {:ok, decrypted_file}

              {:error, error_message} ->
                {:error, "Issue while decrypting file: #{inspect(error_message)}"}
            end

          _ ->
            Logger.error(
              "Issue while loading file. Response code: #{response.status_code} Response Body: #{response.body}"
            )

            {:error, "Issue while loading file."}
        end

      {:error, {error_type, http_status_code, response}} ->
        Logger.error(
          "Issue while loading file. Error type: #{error_type} Response code: #{http_status_code} Response Body: #{response.body}"
        )

        {:error, "Issue while loading file."}
    end
  end

  defp delete_file(id, path) do
    file = bucket_path(id, path)

    # If this request fails, we currently need to manually delete the old files. We could also implement a lifecyle policy, so that this cleanup happens automatically:
    case S3ObjectStorageService.delete_all_objects(bucket_name(), file) do
      {:ok, []} ->
        # this can happen when the files_to_delete is empty. We'll catch this earlier as well to save us a request.
        {:ok}

      {:ok, [response]} ->
        Logger.info("Success while deleting files.")
        Logger.debug("Deleted files: #{response.body}")
        {:ok}

      {:error, {error_type, http_status_code, response}} ->
        Logger.error(
          "Error type: #{error_type} Response code: #{http_status_code} Response Body: #{response.body}"
        )

        {:error, "Files not deleted"}
    end
  end

  defp store_file(filename, file, content_type) do
    case Vault.encrypt(file) do
      {:ok, encrypted_file} ->
        store_encrypted_file(filename, encrypted_file, content_type)

      {:error, error_message} ->
        {:error, "Issue while encrypting file: #{inspect(error_message)}"}
    end
  end

  defp store_encrypted_file(filename, encrypted_file, content_type) do
    case S3ObjectStorageService.put_object(
           bucket_name(),
           bucket_path(filename),
           encrypted_file,
           %{
             content_type: content_type
           }
         ) do
      {:ok, _} ->
        {:ok}

      {:error, {error_type, http_status_code, response}} ->
        Logger.error(
          "Error storing file in bucket: #{filename} Type: #{content_type}. Error type: #{error_type} Response code: #{http_status_code} Response Body: #{response.body}"
        )

        {:error, "Issue while storing file."}
    end
  end

  defp image_filename(id, content_type) do
    id <> ".mp3"
  end

  defp bucket_name do
    System.fetch_env!("OBJECT_STORAGE_BUCKET")
  end

  defp bucket_path(filename) do
    "uploads/#{filename}"
  end
end
