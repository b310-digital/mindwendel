defmodule MindwendelWeb.BrainstormingLive.ShowLinkPreviewTest do
  use MindwendelWeb.ConnCase, async: true
  use Mindwendel.ChatCompletionsCase, async: true
  import Phoenix.LiveViewTest

  alias Mindwendel.Factory

  setup do
    disable_ai()
    brainstorming = Factory.insert!(:brainstorming)
    idea = Factory.insert!(:idea, brainstorming: brainstorming, lane: hd(brainstorming.lanes))
    %{brainstorming: brainstorming, idea: idea}
  end

  test "renders the link preview image from the app origin", %{
    conn: conn,
    brainstorming: brainstorming,
    idea: idea
  } do
    link =
      Factory.insert!(:link,
        idea: idea,
        url: "https://example.test",
        img_preview_url: "https://tracker.test/pixel.png"
      )

    {:ok, view, html} = live(conn, ~p"/brainstormings/#{brainstorming.id}")

    refute html =~ "tracker.test"
    assert has_element?(view, ~s(img.preview-url[src="/links/#{link.id}/preview_image"]))

    html = render(element(view, ".preview-url"))
    refute html =~ "tracker.test"
  end

  test "renders the link preview image from the app origin in the idea details", %{
    conn: conn,
    brainstorming: brainstorming,
    idea: idea
  } do
    link =
      Factory.insert!(:link,
        idea: idea,
        url: "https://example.test",
        img_preview_url: "https://tracker.test/pixel.png"
      )

    {:ok, view, html} =
      live(conn, ~p"/brainstormings/#{brainstorming.id}/ideas/#{idea.id}")

    refute html =~ "tracker.test"

    assert has_element?(
             view,
             ~s(#idea-modal img.preview-url[src="/links/#{link.id}/preview_image"])
           )
  end

  test "renders no link preview image if the link has none", %{
    conn: conn,
    brainstorming: brainstorming,
    idea: idea
  } do
    Factory.insert!(:link, idea: idea, url: "https://example.test", img_preview_url: "")

    {:ok, view, _html} = live(conn, ~p"/brainstormings/#{brainstorming.id}")

    refute has_element?(view, "img.preview-url")
  end
end
