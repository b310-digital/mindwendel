defmodule MindwendelWeb.LinkPreviewControllerTest do
  use MindwendelWeb.ConnCase, async: true

  alias Mindwendel.Factory

  @png <<0x89, "PNG\r\n", 0x1A, "\n", "rest of the image">>

  setup do
    bypass = Bypass.open()
    idea = Factory.insert!(:idea)
    %{bypass: bypass, idea: idea}
  end

  defp insert_link(idea, img_preview_url),
    do:
      Factory.insert!(:link,
        idea: idea,
        url: "http://example.test",
        img_preview_url: img_preview_url
      )

  describe "get_image" do
    test "proxies the preview image", %{conn: conn, bypass: bypass, idea: idea} do
      Bypass.expect_once(bypass, "GET", "/image.png", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "image/png")
        |> Plug.Conn.resp(200, @png)
      end)

      link = insert_link(idea, "http://localhost:#{bypass.port}/image.png")
      response = get(conn, ~p"/links/#{link.id}/preview_image")

      assert response.status == 200
      assert response.resp_body == @png
      assert get_resp_header(response, "content-type") == ["image/png"]
      assert get_resp_header(response, "x-content-type-options") == ["nosniff"]
    end

    test "follows redirects of the image url", %{conn: conn, bypass: bypass, idea: idea} do
      Bypass.expect_once(bypass, "GET", "/old.png", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("location", "/image.png")
        |> Plug.Conn.resp(302, "")
      end)

      Bypass.expect_once(bypass, "GET", "/image.png", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "image/png")
        |> Plug.Conn.resp(200, @png)
      end)

      link = insert_link(idea, "http://localhost:#{bypass.port}/old.png")
      response = get(conn, ~p"/links/#{link.id}/preview_image")

      assert response.status == 200
      assert response.resp_body == @png
    end

    test "returns 404 if the image is too large", %{conn: conn, bypass: bypass, idea: idea} do
      Bypass.expect_once(bypass, "GET", "/image.png", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "image/png")
        |> Plug.Conn.resp(200, @png <> String.duplicate("a", 2_000_000))
      end)

      link = insert_link(idea, "http://localhost:#{bypass.port}/image.png")
      assert get(conn, ~p"/links/#{link.id}/preview_image").status == 404
    end

    test "returns a cacheable 404 if the image can not be fetched", %{conn: conn, idea: idea} do
      link = insert_link(idea, "http://unknown.test/image.png")
      response = get(conn, ~p"/links/#{link.id}/preview_image")

      assert response.status == 404
      assert get_resp_header(response, "cache-control") == ["private, max-age=3600"]
    end

    test "limits the number of fetches per image host", %{conn: conn, idea: idea} do
      # The test resolver does not resolve these hosts, so the fetches fail without
      # network access, but count against the limit. The hosts are only used by
      # this test, so they have their own limit.
      links =
        for url <- [
              "http://images.test/a.png",
              "https://Images.test:8443/b.png?query",
              "http://images.test./c.png"
            ] do
          insert_link(Factory.insert!(:idea), url)
        end

      other_host_link = insert_link(idea, "http://other-images.test/a.png")

      # The rate limit is set to 100 fetches per host in config/test.exs
      for i <- 1..100 do
        link = Enum.at(links, rem(i, length(links)))
        assert get(conn, ~p"/links/#{link.id}/preview_image").status == 404
      end

      for link <- links do
        response = get(conn, ~p"/links/#{link.id}/preview_image")
        assert response.status == 429
        assert get_resp_header(response, "retry-after") == ["3600"]
      end

      assert get(conn, ~p"/links/#{other_host_link.id}/preview_image").status == 404
    end

    test "returns 404 if the upstream response is not an image", %{
      conn: conn,
      bypass: bypass,
      idea: idea
    } do
      Bypass.expect_once(bypass, "GET", "/image.png", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "image/svg+xml")
        |> Plug.Conn.resp(200, "<svg onload='alert(1)'></svg>")
      end)

      link = insert_link(idea, "http://localhost:#{bypass.port}/image.png")
      assert get(conn, ~p"/links/#{link.id}/preview_image").status == 404
    end

    test "returns 404 if the image url is not allowed", %{conn: conn, idea: idea} do
      link = insert_link(idea, "http://169.254.169.254/latest/meta-data")
      assert get(conn, ~p"/links/#{link.id}/preview_image").status == 404
    end

    test "returns 404 if the link has no preview image", %{conn: conn, idea: idea} do
      for img_preview_url <- [nil, ""] do
        link = insert_link(idea, img_preview_url)
        assert get(conn, ~p"/links/#{link.id}/preview_image").status == 404
      end
    end

    test "returns 404 for a non-existent link", %{conn: conn} do
      assert get(conn, ~p"/links/#{Ecto.UUID.generate()}/preview_image").status == 404
    end

    test "returns 404 for an invalid link id", %{conn: conn} do
      assert get(conn, ~p"/links/invalid-id/preview_image").status == 404
    end
  end
end
