defmodule MindwendelWeb.BrainstormingChannelTest do
  use MindwendelWeb.ChannelCase

  alias Mindwendel.Factory
  alias Mindwendel.Brainstormings

  setup do
    %{
      brainstorming: Factory.insert!(:brainstorming)
    }
  end

  describe "subscribe" do
    test "listening for the brainstorming gets updates for ideas", %{brainstorming: brainstorming} do
      idea = Factory.insert!(:idea, brainstorming: brainstorming)

      Brainstormings.subscribe(brainstorming.id)
      Brainstormings.update_idea(idea, %{body: "lalala"})
      assert_received {:idea_updated, idea_updated}
      # It should not be a %Ecto.Association.NotLoaded<association :idea_labels is not loaded>
      assert idea_updated.idea_labels == []
    end

    test "does not receive messages from other brainstormings", %{brainstorming: brainstorming} do
      idea = Factory.insert!(:idea, brainstorming: brainstorming)
      other_brainstorming = Factory.insert!(:brainstorming)

      Brainstormings.subscribe(other_brainstorming.id)
      Brainstormings.update_idea(idea, %{body: "lalala"})
      refute_received {:idea_updated, _}
    end
  end
end
