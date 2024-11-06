defmodule Mindwendel.IdeasFixtures do
  @doc """
  Generate an idea.
  """
  def idea_fixture(attrs \\ %{}) do
    {:ok, idea} =
      attrs
      |> Enum.into(%{
        body: "Mindwendel!"
      })
      |> Mindwendel.Ideas.create_idea()

    idea
  end
end
