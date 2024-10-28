# Sandbox environment with a compatible storage service interface
# Used primarily in tests, could also be used to store files on the server if no other s3 compatible backend is available
defmodule Mindwendel.Services.S3ObjectStorageLocalSandboxService do
  def get_object(_bucket_name, bucket_path) do
    dest = Path.join("priv/static/uploads", Path.basename(bucket_path))
    {:ok, content} = File.read(dest)
    {:ok, %{status_code: 200, body: content}}
  end

  def put_object(_bucket_name, bucket_path, file, _opts) do
    upload_path = "priv/static/uploads"
    File.mkdir_p!(Path.dirname(upload_path))
    dest = Path.join(upload_path, Path.basename(bucket_path))
    File.write(dest, file)
    {:ok, {}}
  end

  def delete_object(_bucket_name, file_to_delete) do
    dest = Path.join("priv/static/uploads", Path.basename(file_to_delete))
    File.rm(dest)
    {:ok, {}}
  end
end
