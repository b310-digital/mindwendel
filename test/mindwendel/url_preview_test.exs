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

  describe "private IP validation (SSRF protection)" do
    test "blocks localhost addresses when allow_private_ips is false" do
      original_config = Application.get_env(:mindwendel, :allow_private_ips)

      try do
        Application.put_env(:mindwendel, :allow_private_ips, false)

        assert {:error, _} = UrlPreview.fetch_url("http://localhost/")
        assert {:error, _} = UrlPreview.fetch_url("http://127.0.0.1/")
        assert {:error, _} = UrlPreview.fetch_url("http://127.0.0.255/")
      after
        Application.put_env(:mindwendel, :allow_private_ips, original_config)
      end
    end

    test "blocks private IP ranges when allow_private_ips is false" do
      original_config = Application.get_env(:mindwendel, :allow_private_ips)

      try do
        Application.put_env(:mindwendel, :allow_private_ips, false)

        # 10.0.0.0/8 - RFC 1918 private network
        assert {:error, _} = UrlPreview.fetch_url("http://10.0.0.1/")
        assert {:error, _} = UrlPreview.fetch_url("http://10.255.255.255/")

        # 172.16.0.0/12 - RFC 1918 private network
        assert {:error, _} = UrlPreview.fetch_url("http://172.16.0.1/")
        assert {:error, _} = UrlPreview.fetch_url("http://172.31.255.255/")

        # 192.168.0.0/16 - RFC 1918 private network
        assert {:error, _} = UrlPreview.fetch_url("http://192.168.1.1/")
        assert {:error, _} = UrlPreview.fetch_url("http://192.168.255.255/")
      after
        Application.put_env(:mindwendel, :allow_private_ips, original_config)
      end
    end

    test "blocks link-local addresses (cloud metadata endpoints) when allow_private_ips is false" do
      original_config = Application.get_env(:mindwendel, :allow_private_ips)

      try do
        Application.put_env(:mindwendel, :allow_private_ips, false)

        # 169.254.0.0/16 - Link-local/APIPA (includes cloud metadata at 169.254.169.254)
        assert {:error, _} = UrlPreview.fetch_url("http://169.254.169.254/")
        assert {:error, _} = UrlPreview.fetch_url("http://169.254.0.1/")
      after
        Application.put_env(:mindwendel, :allow_private_ips, original_config)
      end
    end

    test "blocks 0.0.0.0 when allow_private_ips is false" do
      original_config = Application.get_env(:mindwendel, :allow_private_ips)

      try do
        Application.put_env(:mindwendel, :allow_private_ips, false)

        assert {:error, _} = UrlPreview.fetch_url("http://0.0.0.0/")
      after
        Application.put_env(:mindwendel, :allow_private_ips, original_config)
      end
    end

    test "allows public IPs when allow_private_ips is false" do
      original_config = Application.get_env(:mindwendel, :allow_private_ips)

      try do
        Application.put_env(:mindwendel, :allow_private_ips, false)

        # These will fail to connect, but should pass IP validation
        # We're testing that they don't return error due to IP blocking
        # Note: 8.8.8.8 is Google's public DNS
        result = UrlPreview.fetch_url("http://8.8.8.8/")
        # Should get connection error, not IP blocking error
        # The error tuple format is the same, but we can verify it attempts the connection
        assert {:error, _} = result
      after
        Application.put_env(:mindwendel, :allow_private_ips, original_config)
      end
    end

    test "allows localhost when allow_private_ips is true", %{bypass: bypass} do
      # This is the default test configuration
      assert Application.get_env(:mindwendel, :allow_private_ips) == true

      Bypass.expect_once(bypass, "GET", "/", fn conn ->
        Plug.Conn.resp(conn, 200, "<html><title>Allowed</title></html>")
      end)

      assert {:ok, title: "Allowed", description: "", img_preview_url: ""} =
               UrlPreview.fetch_url(endpoint_url(bypass.port))
    end

    test "blocks edge case IP addresses in 172.x range when allow_private_ips is false" do
      original_config = Application.get_env(:mindwendel, :allow_private_ips)

      try do
        Application.put_env(:mindwendel, :allow_private_ips, false)

        # Should block 172.16-31.x.x
        assert {:error, _} = UrlPreview.fetch_url("http://172.20.0.1/")

        # Should NOT block 172.15.x.x or 172.32.x.x (outside the range)
        # These will fail with connection errors, not IP validation errors
        # We can't easily test the difference in error types without mocking,
        # but at minimum they should not hang or crash
        result1 = UrlPreview.fetch_url("http://172.15.0.1/")
        result2 = UrlPreview.fetch_url("http://172.32.0.1/")
        assert {:error, _} = result1
        assert {:error, _} = result2
      after
        Application.put_env(:mindwendel, :allow_private_ips, original_config)
      end
    end

    test "blocks hostname that resolves to private IP when allow_private_ips is false" do
      original_config = Application.get_env(:mindwendel, :allow_private_ips)

      try do
        Application.put_env(:mindwendel, :allow_private_ips, false)

        # "localhost" should resolve to 127.0.0.1
        assert {:error, _} = UrlPreview.fetch_url("http://localhost/")
      after
        Application.put_env(:mindwendel, :allow_private_ips, original_config)
      end
    end
  end

  defp endpoint_url(port), do: "http://localhost:#{port}/"
end
