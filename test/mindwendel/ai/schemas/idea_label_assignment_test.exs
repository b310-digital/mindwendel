defmodule Mindwendel.AI.Schemas.IdeaLabelAssignmentTest do
  use ExUnit.Case, async: true

  alias Mindwendel.AI.Schemas.IdeaLabelAssignment

  describe "validate_assignments/1" do
    test "returns validated assignments when payload is valid" do
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

      assert {:ok, validated} = IdeaLabelAssignment.validate_assignments(payload)
      assert length(validated) == 2
      assert Enum.at(validated, 0)[:idea_id] == "idea-1"
      assert Enum.at(validated, 0)[:label_ids] == ["label-1", "label-2"]
      assert Enum.at(validated, 1)[:label_ids] == []
    end

    test "includes optional new label suggestions" do
      payload = [
        %{
          "idea_id" => "idea-1",
          "label_ids" => ["label-1"],
          "new_labels" => [
            %{
              "id" => "d2a58c6b-bd15-45ec-9f42-455b54f3506b",
              "name" => "Fresh",
              "color" => "#ff00ff"
            },
            %{"name" => "Brand New"}
          ]
        }
      ]

      assert {:ok, [assignment]} = IdeaLabelAssignment.validate_assignments(payload)

      assert assignment[:new_labels] == [
               %{
                 id: "d2a58c6b-bd15-45ec-9f42-455b54f3506b",
                 name: "Fresh",
                 color: "#ff00ff"
               },
               %{id: nil, name: "Brand New", color: nil}
             ]
    end

    test "returns formatted errors for invalid payload" do
      payload = [
        %{
          "idea_id" => "",
          "label_ids" => "invalid"
        }
      ]

      assert {:error, errors} = IdeaLabelAssignment.validate_assignments(payload)

      assert %{
               0 => %{
                 idea_id: ["can&#39;t be blank"],
                 label_ids: ["is invalid"]
               }
             } = errors
    end

    test "rejects non-list payloads" do
      assert {:error, %{base: ["expected a list of assignments"]}} =
               IdeaLabelAssignment.validate_assignments(%{})
    end
  end
end
