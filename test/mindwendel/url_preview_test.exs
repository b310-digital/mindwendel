defmodule MindwendelServices.UrlPreviewTest do
  use ExUnit.Case
  alias Mindwendel.UrlPreview

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  describe "extract_url" do
    test "extracts url with no other text" do
      assert "http://myname.de" = UrlPreview.extract_url("http://myname.de")
    end

    test "extracts url with wrapping text" do
      assert "http://myname.de" = UrlPreview.extract_url("Some text http://myname.de also here")
    end

    test "extracts first url from different urls" do
      assert "http://myname.de" =
               UrlPreview.extract_url("http://myname.de http://someothername.de")
    end

    test "extracts long url with query params" do
      assert "http://myname.de/blog/1234sometest&query=test" =
               UrlPreview.extract_url("http://myname.de/blog/1234sometest&query=test")
    end

    test "extracts url with final slash" do
      assert "http://myname.de/" = UrlPreview.extract_url("http://myname.de/")
    end

    test "extracts https url with final slash" do
      assert "https://myname.de/" = UrlPreview.extract_url("https://myname.de/")
    end

    test "extracts https url without final slash" do
      assert "https://myname.de" = UrlPreview.extract_url("https://myname.de")
    end

    test "extracts empty string if no url is given" do
      assert UrlPreview.extract_url("No Url here") == ""
    end
  end

  describe "fetch_url" do
    test "fetches title and meta tags", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/some_post", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          "<html><title>Hello mindwendel</title><meta name='description' content='Some text'</meta><meta property='og:image' content='http://some.link.de'></meta></html>"
        )
      end)

      assert {:ok,
              title: "Hello mindwendel",
              description: "Some text",
              img_preview_url: "http://some.link.de"} =
               UrlPreview.fetch_url(endpoint_url(bypass.port) <> "/some_post")
    end

    test "fetches title and meta tags from redirected url", %{bypass: bypass} do
      # Starting another bypass server on a different port
      # and use this server as the final endpoint that the initial request is requested to
      other_bypass = Bypass.open(port: bypass.port + 1)

      Bypass.expect_once(other_bypass, "GET", "", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          "<html><title>Hello mindwendel</title><meta name='description' content='Some text'</meta><meta property='og:image' content='http://some.link.de'></meta></html>"
        )
      end)

      Bypass.expect_once(bypass, "GET", "", fn conn ->
        Phoenix.Controller.redirect(conn, external: endpoint_url(other_bypass.port))
      end)

      assert {:ok,
              title: "Hello mindwendel",
              description: "Some text",
              img_preview_url: "http://some.link.de"} =
               UrlPreview.fetch_url(endpoint_url(bypass.port) <> "")
    end

    test "fetches only the title", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/some_post", fn conn ->
        Plug.Conn.resp(conn, 200, "<html><title>Hello mindwendel</title></html>")
      end)

      assert {:ok, title: "Hello mindwendel", description: "", img_preview_url: ""} =
               UrlPreview.fetch_url(endpoint_url(bypass.port) <> "/some_post")
    end

    test "fetches an error", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/some_post", fn conn ->
        Plug.Conn.resp(conn, 404, "")
      end)

      assert {:error, _} = UrlPreview.fetch_url(endpoint_url(bypass.port) <> "/some_post")
    end
  end

  defp endpoint_url(port), do: "http://localhost:#{port}/"
end
