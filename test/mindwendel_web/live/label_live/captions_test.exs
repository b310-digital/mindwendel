defmodule MindwendelWeb.LabelLive.CaptionsTest do
  alias MindwendelWeb.LabelLive.CaptionsComponent
  alias Mindwendel.Brainstormings
  use MindwendelWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Mindwendel.Factory

  setup do
    %{brainstorming: Factory.insert!(:brainstorming), user: Factory.insert!(:user)}
  end

  test "captions contain all labels", %{
    brainstorming: brainstorming,
    user: user
  } do
    preloaded_braisntorming = Brainstormings.get_brainstorming!(brainstorming.id)

    captions_component =
      render_component(CaptionsComponent,
        id: "captions",
        brainstorming: preloaded_braisntorming,
        current_user: user
      )

    # make sure that there is at least one label in the list:

    assert length(preloaded_braisntorming.labels) > 0

    Enum.each(brainstorming.labels, fn label ->
      assert captions_component =~ label.name
    end)
  end
end
