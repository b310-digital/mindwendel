defmodule MindwendelWeb.LabelLive.CaptionsTest do
  use MindwendelWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Mindwendel.Accounts
  alias Mindwendel.Brainstormings
  alias Mindwendel.Factory

  alias MindwendelWeb.LabelLive.CaptionsComponent

  setup do
    %{brainstorming: Factory.insert!(:brainstorming), user: Factory.insert!(:user)}
  end

  test "captions contain all labels", %{
    brainstorming: brainstorming,
    user: user
  } do
    {:ok, preloaded_brainstorming} = Brainstormings.get_brainstorming(brainstorming.id)
    preloaded_user = Accounts.get_user(user.id)

    captions_component =
      render_component(CaptionsComponent,
        id: "captions",
        brainstorming: preloaded_brainstorming,
        filtered_labels: preloaded_brainstorming.filter_labels_ids,
        current_user: preloaded_user
      )

    # make sure that there is at least one label in the list:

    assert length(preloaded_brainstorming.labels) > 0

    Enum.each(preloaded_brainstorming.labels, fn label ->
      assert captions_component =~ label.name
    end)
  end
end
