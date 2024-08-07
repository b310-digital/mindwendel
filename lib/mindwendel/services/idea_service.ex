defmodule Mindwendel.Services.IdeaService do
  alias Mindwendel.Services.ChatCompletions.ChatCompletionsService
  alias Mindwendel.Ideas

  require Logger

  def idea_generation_enabled? do
    ChatCompletionsService.enabled?()
  end

  def add_ideas_to_brainstorming(brainstorming) do
    if !idea_generation_enabled?() do
      []
    else
      generated_ideas = ChatCompletionsService.generate_ideas(brainstorming.name)

      Enum.map(generated_ideas, fn generated_idea ->
        Ideas.create_idea(%{
          username: "AI",
          body: generated_idea["idea"],
          brainstorming_id: brainstorming.id
        })
      end)
    end
  end
end
