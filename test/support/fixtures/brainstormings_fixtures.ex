defmodule Mindwendel.BrainstormingsFixtures do
  alias Mindwendel.Factory

  @moduledoc """
  This module defines test helpers for creating
  entities via the `Mindwendel.Brainstormings` context.
  """

  @doc """
  Generate a lane.
  """
  def lane_fixture(attrs \\ %{}) do
    {:ok, lane} =
      attrs
      |> Enum.into(%{
        name: "some name",
        position_order: 42,
        brainstorming_id: brainstorming_fixture().id
      })
      |> Mindwendel.Lanes.create_lane()

    lane
  end

  @doc """
  Generate a brainstorming.
  """
  def brainstorming_fixture(user \\ Factory.insert!(:user), attrs \\ %{}) do
    new_attrs =
      attrs
      |> Enum.into(%{
        name: "How to brainstorm ideas?",
        # This can be removed as soon the todo is solved in lib/mindwendel/brainstormings/brainstorming.ex:12
        admin_url_id: Ecto.UUID.generate()
      })

    {:ok, brainstorming} = Mindwendel.Brainstormings.create_brainstorming(user, new_attrs)

    brainstorming
  end

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
