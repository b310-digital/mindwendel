defmodule Mindwendel.Services.ExAwsFinchClientTest do
  use ExUnit.Case, async: true

  alias Mindwendel.Services.ExAwsFinchClient

  # Accepts one connection, forwards the raw request to the test process and
  # answers with the given raw response
  defp start_server(response, opts \\ []) do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen)
    test_pid = self()

    spawn_link(fn ->
      {:ok, socket} = :gen_tcp.accept(listen)
      {:ok, request} = :gen_tcp.recv(socket, 0, 1_000)
      send(test_pid, {:request, request})

      if opts[:stall], do: Process.sleep(:infinity)

      :ok = :gen_tcp.send(socket, response)
      :gen_tcp.close(socket)
    end)

    "http://localhost:#{port}"
  end

  test "returns status, headers and body" do
    url =
      start_server("HTTP/1.1 200 OK\r\ncontent-length: 5\r\nx-amz-request-id: 1\r\n\r\nhello")

    assert {:ok, %{status_code: 200, headers: headers, body: "hello"}} =
             ExAwsFinchClient.request(
               :put,
               url <> "/bucket/key?acl=1",
               "data",
               [
                 {"content-length", "4"}
               ],
               []
             )

    assert {"x-amz-request-id", "1"} in headers
    assert_received {:request, "PUT /bucket/key?acl=1 HTTP/1.1\r\n" <> rest}
    assert String.ends_with?(rest, "\r\n\r\ndata")
  end

  test "skips informational responses" do
    url =
      start_server("HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 204 No Content\r\nx-final: 1\r\n\r\n")

    assert {:ok, %{status_code: 204, headers: [{"x-final", "1"}], body: ""}} =
             ExAwsFinchClient.request(:delete, url <> "/bucket/key", "", [], [])
  end

  test "accepts a body delimited by the server closing the connection" do
    url = start_server("HTTP/1.1 200 OK\r\nconnection: close\r\n\r\nuntil closed")

    assert {:ok, %{status_code: 200, body: "until closed"}} =
             ExAwsFinchClient.request(:get, url <> "/bucket/key", "", [], [])
  end

  test "returns a timeout when the storage does not answer in time" do
    url = start_server("", stall: true)

    {time_us, result} =
      :timer.tc(fn ->
        ExAwsFinchClient.request(:get, url <> "/bucket/key", "", [], timeout: 100)
      end)

    assert result == {:error, %{reason: :timeout}}
    assert time_us < 1_000_000
  end

  test "only returns the error kind, not data sent by the server" do
    url = start_server("SECRET garbage\r\n\r\n")

    assert {:error, %{reason: :invalid_status_line}} =
             ExAwsFinchClient.request(:get, url <> "/bucket/key", "", [], [])
  end

  test "returns an error when the storage is unreachable" do
    {:ok, listen} = :gen_tcp.listen(0, [])
    {:ok, port} = :inet.port(listen)
    :gen_tcp.close(listen)

    assert {:error, %{reason: :econnrefused}} =
             ExAwsFinchClient.request(:get, "http://localhost:#{port}/bucket/key", "", [], [])
  end
end
