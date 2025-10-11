defmodule MindwendelWeb.BrainstormingChannelTest do
  use MindwendelWeb.ChannelCase, async: true

  alias Mindwendel.Brainstormings
  alias Mindwendel.Factory
  alias Mindwendel.Ideas

  setup do
    %{
      brainstorming: Factory.insert!(:brainstorming)
    }
  end

  describe "subscribe" do
    test "listening for the brainstorming gets updates for ideas", %{brainstorming: brainstorming} do
      idea = Factory.insert!(:idea, brainstorming: brainstorming)

      Brainstormings.subscribe(brainstorming.id)
      Ideas.update_idea(idea, %{body: "lalala"})
      assert_received {:lanes_updated, _}
    end

    test "does not receive messages from other brainstormings", %{brainstorming: brainstorming} do
      idea = Factory.insert!(:idea, brainstorming: brainstorming)
      other_brainstorming = Factory.insert!(:brainstorming)

      Brainstormings.subscribe(other_brainstorming.id)
      Ideas.update_idea(idea, %{body: "lalala"})
      refute_received {:idea_updated, _}
    end
  end
end
