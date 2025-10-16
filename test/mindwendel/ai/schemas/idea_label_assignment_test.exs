defmodule Mindwendel.AI.Schemas.IdeaLabelAssignmentTest do
  use ExUnit.Case, async: true

  alias Mindwendel.AI.Schemas.IdeaLabelAssignment

  describe "cast_assignments/1" do
    test "returns structs when payload is valid" do
      payload = [
        %{
          "idea_id" => "idea-1",
          "label_ids" => ["label-1", "label-2"]
        },
        %{
          "idea_id" => "idea-2",
          "label_ids" => []
        }
      ]

      assert {:ok, assignments} = IdeaLabelAssignment.cast_assignments(payload)
      assert length(assignments) == 2

      assignments_by_id =
        assignments
        |> Enum.into(%{}, fn %IdeaLabelAssignment{idea_id: idea_id} = assignment ->
          {idea_id, assignment}
        end)

      assert assignments_by_id["idea-1"].label_ids == ["label-1", "label-2"]
      assert assignments_by_id["idea-2"].label_ids == []
    end

    test "returns formatted errors for invalid payload entries" do
      payload = [
        %{
          "idea_id" => "",
          "label_ids" => "invalid"
        }
      ]

      assert {:error, errors} = IdeaLabelAssignment.cast_assignments(payload)
      assert %{0 => %{base: ["invalid assignment data"]}} = errors
    end

    test "rejects non-list payloads" do
      assert {:error, %{base: ["expected a list of assignments"]}} =
               IdeaLabelAssignment.cast_assignments(%{})
    end
  end
end
