defmodule Mindwendel.Services.StorageService do
  alias Mindwendel.Services.Vault
  require Logger

  def store_file(filename, file_path, content_type, s3_client \\ storage_provider()) do
    case File.read(file_path) do
      {:ok, file} ->
        case Vault.encrypt(file) do
          {:ok, encrypted_file} ->
            store_encrypted_file(filename, encrypted_file, content_type, s3_client)

          {:error, error_message} ->
            {:error, "Issue while encrypting file: #{inspect(error_message)}"}
        end

      {:error, reason} ->
        Logger.error("Failed to read file #{file_path}: #{inspect(reason)}")
        {:error, "Failed to read file: #{inspect(reason)}"}
    end
  end

  def get_file(file_path, s3_client \\ storage_provider()) do
    case s3_client.get_object(bucket_name(), file_path) do
      {:ok, response} ->
        case response.status_code do
          200 ->
            decrypt_response_body(response.body)

          _ ->
            Logger.error("Issue while loading file. Response code: #{response.status_code}")

            {:error, "Issue while loading file."}
        end

      {:error, reason} ->
        Logger.error("Issue while loading file: #{describe_error(reason)}")
        {:error, "Issue while loading file."}
    end
  end

  def delete_file(path, s3_client \\ storage_provider()) do
    case s3_client.delete_object(bucket_name(), path) do
      {:ok, _} ->
        Logger.info("Successfully deleted file #{path}.")
        {:ok}

      {:error, reason} ->
        Logger.error("Issue while deleting file: #{describe_error(reason)}")
        {:error, "Files not deleted"}
    end
  end

  defp store_encrypted_file(filename, encrypted_file, content_type, s3_client) do
    encrypted_file_path = upload_path(filename)

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

      {:error, reason} ->
        Logger.error(
          "Error storing file in bucket: #{filename} Type: #{content_type}. Reason: #{describe_error(reason)}"
        )

        {:error, "Issue while storing file."}
    end
  end

  # Only log the error kind, since storage errors can contain response bodies
  # and headers of the object storage
  defp describe_error({:http_error, status, _response}), do: "HTTP #{status}"
  defp describe_error(reason) when is_atom(reason), do: Atom.to_string(reason)

  defp describe_error(reason) when is_tuple(reason) and is_atom(elem(reason, 0)),
    do: Atom.to_string(elem(reason, 0))

  # Typed AWS errors, e.g. {"ThrottlingException", message}
  defp describe_error(reason) when is_tuple(reason) and is_binary(elem(reason, 0)),
    do: String.slice(elem(reason, 0), 0, 100)

  defp describe_error(_reason), do: "unknown error"

  defp decrypt_response_body(body) do
    case Vault.decrypt(body) do
      {:ok, decrypted_file} ->
        {:ok, decrypted_file}

      {:error, error_message} ->
        {:error, "Issue while decrypting file: #{inspect(error_message)}"}
    end
  end

  defp bucket_name do
    System.fetch_env!("OBJECT_STORAGE_BUCKET")
  end

  defp upload_path(filename) do
    "uploads/encrypted-#{filename}"
  end

  defp storage_provider do
    Application.get_env(:mindwendel, :s3_storage_provider)
  end
end
