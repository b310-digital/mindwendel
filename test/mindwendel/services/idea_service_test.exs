defmodule Mindwendel.Services.IdeaServiceTest do
  alias Mindwendel.Services.IdeaService
  use Mindwendel.DataCase
  use Mindwendel.ChatCompletionsCase
  alias Mindwendel.Factory
  alias Mindwendel.Brainstormings
  alias Mindwendel.Accounts.User

  setup do
    brainstorming = Factory.insert!(:brainstorming)
    mock_ai_enabled?(true)
    %{brainstorming: brainstorming}
  end

  describe "add_ideas_to_brainstorming/1" do
    test "returns the 5 most recent brainstormings", %{brainstorming: brainstorming} do
      idea_count = 3
      mock_generate_ideas(idea_count)
      ideas = IdeaService.add_ideas_to_brainstorming(brainstorming)
      assert length(ideas) == idea_count
      assert length(Brainstormings.get_brainstorming!(brainstorming.id).ideas) == idea_count
    end

    test "does not create user", %{brainstorming: brainstorming} do
      initial_user_count = Repo.aggregate(User, :count, :id)
      idea_count = 3
      mock_generate_ideas(idea_count)

      IdeaService.add_ideas_to_brainstorming(brainstorming)
      assert initial_user_count == Repo.aggregate(User, :count, :id)
    end
  end
end
