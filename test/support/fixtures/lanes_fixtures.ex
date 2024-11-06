defmodule Mindwendel.LanesFixtures do
  alias Mindwendel.BrainstormingsFixtures

  @doc """
  Generate a lane.
  """
  def lane_fixture(attrs \\ %{}) do
    {:ok, lane} =
      attrs
      |> Enum.into(%{
        name: "some name",
        position_order: 42,
        brainstorming_id: BrainstormingsFixtures.brainstorming_fixture().id
      })
      |> Mindwendel.Lanes.create_lane()

    lane
  end
end
