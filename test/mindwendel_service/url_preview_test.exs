defmodule MindwendelServices.UrlPreviewTest do
  use ExUnit.Case
  alias MindwendelService.UrlPreview

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  describe "extract_url" do
    test "extracts the url with no other text" do
      assert "http://jannikstreek.de" = UrlPreview.extract_url("http://jannikstreek.de")
    end

    test "extracts the url with wrapping text" do
      assert "http://jannikstreek.de" =
               UrlPreview.extract_url("Some text http://jannikstreek.de also here")
    end

    test "extracts only the first url" do
      assert "http://jannikstreek.de" =
               UrlPreview.extract_url("http://jannikstreek.de http://gerardonicho.de")
    end

    test "extracts the url with query params" do
      assert "http://jannikstreek.de/blog/1234sometest&query=test" =
               UrlPreview.extract_url("http://jannikstreek.de/blog/1234sometest&query=test")
    end

    test "extracts empty string if no url is given" do
      assert "" = UrlPreview.extract_url("No Url here")
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
  end

  defp endpoint_url(port), do: "http://localhost:#{port}/"
end
