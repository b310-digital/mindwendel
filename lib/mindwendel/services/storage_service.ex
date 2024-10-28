defmodule Mindwendel.Services.StorageService do
  alias Mindwendel.Services.S3ObjectStorageService
  alias Mindwendel.Services.Vault
  require Logger

  def store_file(filename, file_path, content_type, s3_client \\ S3ObjectStorageService) do
    {:ok, file} = File.read(file_path)

    case Vault.encrypt(file) do
      {:ok, encrypted_file} ->
        store_encrypted_file(filename, encrypted_file, content_type, s3_client)

      {:error, error_message} ->
        {:error, "Issue while encrypting file: #{inspect(error_message)}"}
    end
  end

  def get_file(file_path, s3_client \\ S3ObjectStorageService) do
    case s3_client.get_object(bucket_name(), file_path) do
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

  def delete_file(path, s3_client \\ S3ObjectStorageService) do
    case s3_client.delete_object(bucket_name(), path) do
      {:ok, _} ->
        Logger.info("Successfully deleted file #{path}.")
        {:ok}

      {:error, {error_type, http_status_code, response}} ->
        Logger.error(
          "Error type: #{error_type} Response code: #{http_status_code} Response Body: #{response.body}"
        )

        {:error, "Files not deleted"}
    end
  end

  defp store_encrypted_file(filename, encrypted_file, content_type, s3_client) do
    encrypted_file_path = bucket_path(filename)

    case s3_client.put_object(
           bucket_name(),
           encrypted_file_path,
           encrypted_file,
           %{
             content_type: content_type
           }
         ) do
      {:ok, _headers} ->
        {:ok, encrypted_file_path}

      {:error, {error_type, http_status_code, response}} ->
        Logger.error(
          "Error storing file in bucket: #{filename} Type: #{content_type}. Error type: #{error_type} Response code: #{http_status_code} Response Body: #{response.body}"
        )

        {:error, "Issue while storing file."}
    end
  end

  defp bucket_name do
    System.fetch_env!("OBJECT_STORAGE_BUCKET")
  end

  defp bucket_path(filename) do
    "uploads/encrypted-#{filename}"
  end
end
