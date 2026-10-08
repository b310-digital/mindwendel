defmodule Mindwendel.Services.ExAwsFinchClient do
  @moduledoc """
  ExAws HTTP client based on Finch, as ExAws defaults to hackney, which is not
  a dependency of mindwendel.

  The `:timeout` http option (in ms) limits the whole request.
  """
  @behaviour ExAws.Request.HttpClient

  # ExAws retries up to 3 times (see config.exs), which has to stay below the
  # LiveView push timeout of 30s
  @default_timeout 8_000

  @impl true
  def request(method, url, body, headers, http_opts) do
    timeout = Keyword.get(http_opts, :timeout, @default_timeout)

    method
    |> Finch.build(url, headers, body)
    |> Finch.request(Mindwendel.Finch, request_timeout: timeout, receive_timeout: timeout)
    |> case do
      {:ok, %Finch.Response{status: status, headers: headers, body: body}} ->
        {:ok, %{status_code: status, headers: headers, body: body}}

      {:error, exception} ->
        {:error, %{reason: error_kind(exception)}}
    end
  end

  # ExAws logs the reason. Some errors contain data sent by the server,
  # e.g. {:invalid_status_line, line}, so only the kind is passed on.
  defp error_kind(%{reason: reason}) when is_atom(reason), do: reason

  defp error_kind(%{reason: reason}) when is_tuple(reason) and is_atom(elem(reason, 0)),
    do: elem(reason, 0)

  defp error_kind(_exception), do: :unknown_error
end
