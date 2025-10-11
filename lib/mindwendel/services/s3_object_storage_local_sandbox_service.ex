# Sandbox environment with a compatible storage service interface
# Used primarily in tests. Could also store files on the server if no other
# s3 compatible backend is available.
defmodule Mindwendel.Services.S3ObjectStorageLocalSandboxService do
  def get_object(_bucket_name, bucket_path) do
    dest = build_local_path(bucket_path)
    {:ok, content} = File.read(dest)
    {:ok, %{status_code: 200, body: content}}
  end

  def put_object(_bucket_name, bucket_path, file, _opts) do
    dest = build_local_path(bucket_path)
    File.mkdir_p!(Path.dirname(dest))

    File.write(dest, file)
    {:ok, {}}
  end

  def delete_object(_bucket_name, file_to_delete) do
    dest = build_local_path(file_to_delete)
    File.rm(dest)
    {:ok, {}}
  end

  defp build_local_path(bucket_path) do
    trimmed = String.trim_leading(bucket_path, "/")
    Path.join("priv/static", trimmed)
  end
end
