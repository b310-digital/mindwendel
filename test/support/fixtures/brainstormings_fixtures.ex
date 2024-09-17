defmodule Mindwendel.BrainstormingsFixtures do
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
        position_order: 42
      })
      |> Mindwendel.Brainstormings.create_lane()

    lane
  end
end
