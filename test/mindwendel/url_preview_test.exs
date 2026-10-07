defmodule MindwendelServices.UrlPreviewTest do
  use ExUnit.Case, async: true
  alias Mindwendel.UrlPreview

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  describe "extract_url" do
    test "extracts the url with no other text" do
      assert "http://myname.de" = UrlPreview.extract_url("http://myname.de")
    end

    test "extracts the url with wrapping text" do
      assert "http://myname.de" = UrlPreview.extract_url("Some text http://myname.de also here")
    end

    test "extracts only the first url" do
      assert "http://myname.de" =
               UrlPreview.extract_url("http://myname.de http://someothername.de")
    end

    test "extracts the url with query params" do
      assert "http://myname.de/blog/1234sometest&query=test" =
               UrlPreview.extract_url("http://myname.de/blog/1234sometest&query=test")
    end

    test "extracts empty string if no url is given" do
      assert "" = UrlPreview.extract_url("No Url here")
    end

    test "extracts empty string for empty string" do
      assert "" = UrlPreview.extract_url("")
    end

    test "extracts https urls" do
      assert "https://secure.example.com" =
               UrlPreview.extract_url("Check out https://secure.example.com")
    end

    test "extracts urls with complex paths" do
      assert "https://example.com/path/to/resource?foo=bar&baz=qux#anchor" =
               UrlPreview.extract_url(
                 "https://example.com/path/to/resource?foo=bar&baz=qux#anchor"
               )
    end
  end

  describe "fetch_url" do
    test "fetches title and meta tags", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/some_post", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          "<html><title>Hi!</title><meta name='description' content='Some text'</meta><meta property='og:image' content='http//some.link.de'></meta></html>"
        )
      end)

      assert {:ok, title: "Hi!", description: "Some text", img_preview_url: "http//some.link.de"} =
               UrlPreview.fetch_url(endpoint_url(bypass.port) <> "/some_post")
    end

    test "fetches only the title", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/some_post", fn conn ->
        Plug.Conn.resp(conn, 200, "<html><title>Hi!</title></html>")
      end)

      assert {:ok, title: "Hi!", description: "", img_preview_url: ""} =
               UrlPreview.fetch_url(endpoint_url(bypass.port) <> "/some_post")
    end

    test "fetches an error", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/some_post", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert {:error, _} = UrlPreview.fetch_url(endpoint_url(bypass.port) <> "/some_post")
    end

    test "truncates long titles to 300 characters", %{bypass: bypass} do
      long_title = String.duplicate("A", 400)

      Bypass.expect_once(bypass, "GET", "/long_title", fn conn ->
        Plug.Conn.resp(conn, 200, "<html><title>#{long_title}</title></html>")
      end)

      assert {:ok, title: title, description: "", img_preview_url: ""} =
               UrlPreview.fetch_url(endpoint_url(bypass.port) <> "/long_title")

      assert String.length(title) == 300
    end

    test "truncates long descriptions to 300 characters", %{bypass: bypass} do
      long_desc = String.duplicate("B", 400)

      Bypass.expect_once(bypass, "GET", "/long_desc", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          "<html><title>Title</title><meta name='description' content='#{long_desc}'></html>"
        )
      end)

      assert {:ok, title: "Title", description: description, img_preview_url: ""} =
               UrlPreview.fetch_url(endpoint_url(bypass.port) <> "/long_desc")

      assert String.length(description) == 300
    end

    test "handles malformed HTML gracefully", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/malformed", fn conn ->
        Plug.Conn.resp(conn, 200, "<html><title>Unclosed title<body>Content</html>")
      end)

      assert {:ok, _} = UrlPreview.fetch_url(endpoint_url(bypass.port) <> "/malformed")
    end

    test "handles various HTTP error codes", %{bypass: bypass} do
      for status_code <- [301, 302, 400, 401, 403, 500, 502, 503] do
        Bypass.expect_once(bypass, "GET", "/status_#{status_code}", fn conn ->
          Plug.Conn.resp(conn, status_code, "")
        end)

        assert {:error, _} =
                 UrlPreview.fetch_url(endpoint_url(bypass.port) <> "/status_#{status_code}")
      end
    end

    test "returns error for invalid URI" do
      assert {:error, _} = UrlPreview.fetch_url("not a valid uri")
    end

    test "returns error for empty URL" do
      assert {:error, _} = UrlPreview.fetch_url("")
    end

    test "returns error for non-HTTP schemes" do
      assert {:error, _} = UrlPreview.fetch_url("ftp://example.com")
      assert {:error, _} = UrlPreview.fetch_url("file:///etc/passwd")
      assert {:error, _} = UrlPreview.fetch_url("javascript:alert(1)")
    end

    test "handles connection errors gracefully", %{bypass: bypass} do
      Bypass.down(bypass)

      assert {:error, _} = UrlPreview.fetch_url(endpoint_url(bypass.port) <> "/some_post")
    end
  end

  describe "fetch_body (SSRF protection)" do
    test "connects to the resolved and validated IP and keeps the Host header", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/", fn conn ->
        assert Plug.Conn.get_req_header(conn, "host") == ["preview.test:#{bypass.port}"]
        Plug.Conn.resp(conn, 200, "ok")
      end)

      assert {:ok, "ok"} =
               UrlPreview.fetch_body("http://preview.test:#{bypass.port}/",
                 resolver: fn "preview.test" -> {:ok, [{127, 0, 0, 1}]} end
               )
    end

    test "rejects a host if any resolved address is not public" do
      resolver = fn "rebind.test" -> {:ok, [{93, 184, 216, 34}, {0, 0, 0, 0, 0, 0, 0, 1}]} end

      assert {:error, :forbidden_address} =
               UrlPreview.fetch_body("http://rebind.test/", resolver: resolver, allowed_ips: [])
    end

    test "rejects a host with an internal AAAA record" do
      resolver = fn "aaaa.test" -> {:ok, [{93, 184, 216, 34}, {0xFD00, 0, 0, 0, 0, 0, 0, 1}]} end

      assert {:error, :forbidden_address} =
               UrlPreview.fetch_body("http://aaaa.test/", resolver: resolver, allowed_ips: [])
    end

    test "rejects hosts that do not resolve" do
      assert {:error, :nxdomain} =
               UrlPreview.fetch_body("http://unknown.test/",
                 resolver: fn _ -> {:error, :nxdomain} end
               )
    end

    test "rejects IP literals of internal ranges" do
      for url <- [
            "http://127.0.0.1/",
            "http://0.0.0.0/",
            "http://10.0.0.1/",
            "http://100.64.0.1/",
            "http://169.254.169.254/",
            "http://172.16.0.1/",
            "http://192.168.1.1/",
            "http://[::1]/",
            "http://[::]/",
            "http://[::ffff:127.0.0.1]/",
            "http://[::ffff:169.254.169.254]/",
            "http://[fd00::1]/",
            "http://[fe80::1]/"
          ] do
        assert {:error, :forbidden_address} = UrlPreview.fetch_body(url, allowed_ips: []), url
      end
    end

    test "re-validates the target of every redirect", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/redirect", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "http://169.254.169.254/latest/meta-data/")
        |> Plug.Conn.resp(302, "")
      end)

      assert {:error, :forbidden_address} =
               UrlPreview.fetch_body(endpoint_url(bypass.port) <> "redirect")
    end

    test "re-resolves and validates hostnames of redirect targets", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/redirect", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "http://internal.test/")
        |> Plug.Conn.resp(301, "")
      end)

      resolver = fn
        "localhost" -> {:ok, [{127, 0, 0, 1}]}
        "internal.test" -> {:ok, [{100, 64, 0, 1}]}
      end

      assert {:error, :forbidden_address} =
               UrlPreview.fetch_body(endpoint_url(bypass.port) <> "redirect", resolver: resolver)
    end

    test "follows redirects to allowed targets", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/old", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "/new")
        |> Plug.Conn.resp(307, "")
      end)

      Bypass.expect_once(bypass, "GET", "/new", fn conn ->
        Plug.Conn.resp(conn, 200, "<title>New</title>")
      end)

      assert {:ok, "<title>New</title>"} =
               UrlPreview.fetch_body(endpoint_url(bypass.port) <> "old")
    end

    test "stops after too many redirects", %{bypass: bypass} do
      Bypass.expect(bypass, "GET", "/loop", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "/loop")
        |> Plug.Conn.resp(302, "")
      end)

      assert {:error, :too_many_redirects} =
               UrlPreview.fetch_body(endpoint_url(bypass.port) <> "loop", max_redirects: 2)
    end

    test "rejects redirects to non-http schemes", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/redirect", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "file:///etc/passwd")
        |> Plug.Conn.resp(302, "")
      end)

      assert {:error, :invalid_url} =
               UrlPreview.fetch_body(endpoint_url(bypass.port) <> "redirect")
    end

    test "caps the response size", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/big", fn conn ->
        Plug.Conn.resp(conn, 200, "<title>Hi</title>" <> String.duplicate("A", 100_000))
      end)

      assert {:ok, body} =
               UrlPreview.fetch_body(endpoint_url(bypass.port) <> "big", max_body_size: 1_000)

      assert byte_size(body) <= 1_000
      assert String.starts_with?(body, "<title>Hi</title>")
    end

    test "caps the total request time" do
      # Each chunk arrives before a per-read timeout would fire
      port =
        serve_raw(fn socket ->
          :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\ntransfer-encoding: chunked\r\n\r\n")

          Enum.each(1..40, fn _ ->
            Process.sleep(50)
            :gen_tcp.send(socket, "1\r\nx\r\n")
          end)
        end)

      {elapsed_us, result} =
        :timer.tc(fn ->
          UrlPreview.fetch_body("http://127.0.0.1:#{port}/slow", timeout: 300)
        end)

      assert {:error, :timeout} = result
      assert elapsed_us < 1_000_000
    end

    test "caps the size of response headers" do
      port =
        serve_raw(fn socket ->
          :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\nx-big: ")
          Enum.each(1..100, fn _ -> :gen_tcp.send(socket, String.duplicate("a", 10_000)) end)
        end)

      assert {:error, :response_too_large} =
               UrlPreview.fetch_body("http://127.0.0.1:#{port}/", max_body_size: 1_000)
    end

    test "includes DNS resolution in the total request time" do
      slow_resolver = fn _host ->
        Process.sleep(2_000)
        {:ok, [{93, 184, 216, 34}]}
      end

      {elapsed_us, result} =
        :timer.tc(fn ->
          UrlPreview.fetch_body("http://slow-dns.test/", resolver: slow_resolver, timeout: 200)
        end)

      assert {:error, :timeout} = result
      assert elapsed_us < 1_000_000
    end

    test "rejects invalid ports" do
      assert {:error, :invalid_url} = UrlPreview.fetch_body("http://example.com:99999/")
      assert {:error, :invalid_url} = UrlPreview.fetch_body("http://example.com:0/")
    end

    test "skips informational responses before the final response" do
      port =
        serve_raw(fn socket ->
          :gen_tcp.send(
            socket,
            "HTTP/1.1 103 Early Hints\r\nlink: </style.css>\r\n\r\n" <>
              "HTTP/1.1 200 OK\r\ncontent-length: 2\r\n\r\nok"
          )
        end)

      assert {:ok, "ok"} = UrlPreview.fetch_body("http://127.0.0.1:#{port}/")
    end

    test "sends a valid Host header for IPv6 literals" do
      test_pid = self()

      port =
        serve_raw(
          fn socket ->
            {:ok, request} = :gen_tcp.recv(socket, 0, 1_000)
            send(test_pid, {:request, request})
            :gen_tcp.send(socket, "HTTP/1.1 200 OK\r\ncontent-length: 2\r\n\r\nok")
          end,
          {0, 0, 0, 0, 0, 0, 0, 1}
        )

      assert {:ok, "ok"} = UrlPreview.fetch_body("http://[::1]:#{port}/")
      assert_receive {:request, request}
      assert request =~ "host: [::1]:#{port}\r\n"
    end
  end

  describe "public_address?" do
    test "rejects non-public IPv4 addresses" do
      for ip <- [
            {0, 0, 0, 0},
            {0, 1, 2, 3},
            {10, 0, 0, 1},
            {100, 64, 0, 1},
            {100, 127, 255, 254},
            {127, 0, 0, 1},
            {127, 255, 255, 255},
            {169, 254, 169, 254},
            {172, 16, 0, 1},
            {172, 31, 255, 255},
            {192, 0, 0, 1},
            {192, 0, 2, 1},
            {192, 168, 0, 1},
            {198, 18, 0, 1},
            {198, 51, 100, 1},
            {203, 0, 113, 1},
            {224, 0, 0, 1},
            {240, 0, 0, 1},
            {255, 255, 255, 255}
          ] do
        refute UrlPreview.public_address?(ip), inspect(ip)
      end
    end

    test "rejects non-public IPv6 addresses" do
      for ip <- [
            # unspecified, loopback
            {0, 0, 0, 0, 0, 0, 0, 0},
            {0, 0, 0, 0, 0, 0, 0, 1},
            # IPv4-mapped loopback / metadata
            {0, 0, 0, 0, 0, 0xFFFF, 0x7F00, 1},
            {0, 0, 0, 0, 0, 0xFFFF, 0xA9FE, 0xA9FE},
            # IPv4-translated (RFC 2765)
            {0, 0, 0, 0, 0xFFFF, 0, 0x7F00, 1},
            # IPv4-compatible (deprecated)
            {0, 0, 0, 0, 0, 0, 0x0A00, 1},
            # NAT64 embedding a private address
            {0x64, 0xFF9B, 0, 0, 0, 0, 0x0A00, 1},
            # 6to4 embedding a private address
            {0x2002, 0x0A00, 0x0001, 0, 0, 0, 0, 1},
            # ULA, link-local, site-local, multicast
            {0xFC00, 0, 0, 0, 0, 0, 0, 1},
            {0xFD00, 0, 0, 0, 0, 0, 0, 1},
            {0xFE80, 0, 0, 0, 0, 0, 0, 1},
            {0xFEC0, 0, 0, 0, 0, 0, 0, 1},
            {0xFF02, 0, 0, 0, 0, 0, 0, 1},
            # documentation, Teredo
            {0x2001, 0x0DB8, 0, 0, 0, 0, 0, 1},
            {0x2001, 0, 0, 0, 0, 0, 0, 1}
          ] do
        refute UrlPreview.public_address?(ip), inspect(ip)
      end
    end

    test "accepts public addresses" do
      for ip <- [
            {8, 8, 8, 8},
            {93, 184, 216, 34},
            {100, 63, 255, 255},
            {100, 128, 0, 0},
            {172, 15, 255, 255},
            {172, 32, 0, 0},
            {0x2001, 0x4860, 0x4860, 0, 0, 0, 0, 0x8888},
            {0x2A00, 0x1450, 0x4001, 0x81C, 0, 0, 0, 0x200E},
            {0, 0, 0, 0, 0, 0xFFFF, 0x0808, 0x0808},
            {0x64, 0xFF9B, 0, 0, 0, 0, 0x0808, 0x0808}
          ] do
        assert UrlPreview.public_address?(ip), inspect(ip)
      end
    end
  end

  # A raw socket server for responses Bypass can't produce (Bypass also kills
  # the handler when the client disconnects)
  defp serve_raw(handler, ip \\ {127, 0, 0, 1}) do
    {:ok, listen_socket} =
      :gen_tcp.listen(
        0,
        [:binary, active: false, ip: ip] ++ if(tuple_size(ip) == 8, do: [:inet6], else: [])
      )

    {:ok, port} = :inet.port(listen_socket)

    spawn_link(fn ->
      {:ok, socket} = :gen_tcp.accept(listen_socket)
      handler.(socket)
      Process.sleep(:infinity)
    end)

    port
  end

  defp endpoint_url(port), do: "http://localhost:#{port}/"
end
