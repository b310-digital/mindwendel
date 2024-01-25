defmodule MindwendelServices.UrlPreviewTest do
  use ExUnit.Case
  alias Mindwendel.UrlPreview

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  describe "extract_url" do
    test "extracts the url with no other text" do
      assert UrlPreview.extract_url("http://myname.de") == "http://myname.de"
    end

    test "extracts the url with wrapping text" do
      assert UrlPreview.extract_url("Some text http://myname.de also here") == "http://myname.de"
    end

    test "extracts only the first url" do
      assert UrlPreview.extract_url("http://myname.de http://someothername.de") ==
               "http://myname.de"
    end

    test "extracts the url with query params" do
      assert UrlPreview.extract_url("http://myname.de/blog/1234sometest&query=test") ==
               "http://myname.de/blog/1234sometest&query=test"
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

    test "fetches title and meta tags with redirect", %{bypass: bypass} do
      # Start another bypass server on a different port
      other_bypass = Bypass.open(port: bypass.port + 1)

      Bypass.expect_once(other_bypass, "GET", "", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          ~H"""
            <html>
            <title>Hello mindwendel</title><meta name='description' content='Some text'</meta><meta property='og:image' content='http://some.link.de'></meta></html>
          """
          # "<html><title>Hello mindwendel</title><meta name='description' content='Some text'</meta><meta property='og:image' content='http://some.link.de'></meta></html>"
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
