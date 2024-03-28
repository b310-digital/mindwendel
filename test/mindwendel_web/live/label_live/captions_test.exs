defmodule MindwendelWeb.LabelLive.CaptionsTest do
  alias MindwendelWeb.LabelLive.CaptionsComponent
  use MindwendelWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Mindwendel.Factory

  setup do
    %{brainstorming: Factory.insert!(:brainstorming)}
  end

  test "captions contain all labels", %{
    brainstorming: brainstorming
  } do
    captions_component = render_component(CaptionsComponent, brainstorming: brainstorming)

    # make sure that there is at least one label in the list:
    assert Enum.count(brainstorming.labels) > 0

    Enum.each(brainstorming.labels, fn label ->
      assert captions_component =~ label.name
    end)
  end
end
