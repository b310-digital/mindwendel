defmodule Mindwendel.Services.ExAwsMintClient do
  @moduledoc """
  ExAws HTTP client based on Mint, which is already used for the url previews.

  ExAws defaults to hackney, which is not a dependency of mindwendel. A new
  connection is opened per request, which is fine for the low volume of
  file uploads.

  The `:timeout` http option (in ms) limits the whole request, including
  connecting, so a slow storage cannot block the caller longer than that.
  """
  @behaviour ExAws.Request.HttpClient

  # ExAws retries up to 3 times (see config.exs), which has to stay below the
  # LiveView push timeout of 30s
  @default_timeout 8_000

  @impl true
  def request(method, url, body, headers, http_opts) do
    deadline =
      System.monotonic_time(:millisecond) + Keyword.get(http_opts, :timeout, @default_timeout)

    uri = URI.parse(url)
    method = method |> Atom.to_string() |> String.upcase()
    body = if body == "", do: nil, else: body

    with {:ok, conn} <- connect(uri, deadline) do
      try do
        with {:ok, conn, ref} <- send_request(conn, method, uri, headers, body) do
          receive_response(conn, ref, %{status_code: nil, headers: [], body: []}, deadline)
        end
      after
        Mint.HTTP.close(conn)
      end
    end
    |> case do
      {:ok, response} -> {:ok, %{response | body: IO.iodata_to_binary(response.body)}}
      {:error, %{reason: reason}} -> {:error, %{reason: error_kind(reason)}}
      {:error, reason} -> {:error, %{reason: error_kind(reason)}}
    end
  end

  # ExAws logs the reason. Some Mint errors contain data sent by the server,
  # e.g. {:invalid_status_line, line}, so only the kind is passed on.
  defp error_kind(reason) when is_tuple(reason) and is_atom(elem(reason, 0)), do: elem(reason, 0)
  defp error_kind(reason) when is_atom(reason), do: reason
  defp error_kind(_reason), do: :unknown_error

  defp connect(uri, deadline) do
    scheme = if uri.scheme == "https", do: :https, else: :http

    case remaining_time(deadline) do
      0 ->
        {:error, :timeout}

      timeout ->
        Mint.HTTP.connect(scheme, uri.host, uri.port,
          mode: :passive,
          protocols: [:http1],
          transport_opts: [timeout: timeout]
        )
    end
  end

  defp send_request(conn, method, uri, headers, body) do
    case Mint.HTTP.request(conn, method, request_target(uri), headers, body) do
      {:ok, conn, ref} -> {:ok, conn, ref}
      {:error, _conn, reason} -> {:error, reason}
    end
  end

  defp request_target(%URI{path: path, query: query}) do
    path = if path in [nil, ""], do: "/", else: path
    if query, do: path <> "?" <> query, else: path
  end

  defp receive_response(conn, ref, response, deadline) do
    with timeout when timeout > 0 <- remaining_time(deadline),
         {:ok, conn, responses} <- Mint.HTTP.recv(conn, 0, timeout) do
      case handle_responses(responses, response, ref) do
        {:done, response} -> {:ok, response}
        response -> receive_response(conn, ref, response, deadline)
      end
    else
      0 ->
        {:error, :timeout}

      {:error, _conn, reason, _responses} ->
        {:error, reason}
    end
  end

  defp handle_responses(responses, response, ref),
    do: Enum.reduce(responses, response, &handle_response(&1, &2, ref))

  # A new status resets the headers, so informational (1xx) responses are dropped
  defp handle_response({:status, ref, status}, response, ref),
    do: %{response | status_code: status, headers: []}

  defp handle_response({:headers, ref, headers}, response, ref),
    do: %{response | headers: response.headers ++ headers}

  defp handle_response({:data, ref, data}, response, ref),
    do: %{response | body: [response.body, data]}

  defp handle_response({:done, ref}, response, ref), do: {:done, response}
  defp handle_response(_other, response, _ref), do: response

  defp remaining_time(deadline), do: max(deadline - System.monotonic_time(:millisecond), 0)
end
