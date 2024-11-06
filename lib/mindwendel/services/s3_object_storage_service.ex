defmodule Mindwendel.Services.S3ObjectStorageService do
  alias ExAws.S3

  require Logger

  def get_object(bucket_name, bucket_path) do
    S3.get_object(bucket_name, bucket_path) |> ExAws.request()
  end

  def put_object(bucket_name, bucket_path, file, opts) do
    S3.put_object(bucket_name, bucket_path, file, opts) |> ExAws.request()
  end

  def delete_object(bucket_name, file_to_delete) do
    S3.delete_object(bucket_name, file_to_delete) |> ExAws.request()
  end
end
