defmodule Mindwendel.AI.Schemas.IdeaResponseTest do
  use ExUnit.Case, async: true

  alias Mindwendel.AI.Schemas.IdeaResponse

  describe "changeset/2" do
    test "valid idea with only required fields" do
      attrs = %{"idea" => "This is a valid idea"}
      changeset = IdeaResponse.changeset(%IdeaResponse{}, attrs)

      assert changeset.valid?
      assert changeset.changes.idea == "This is a valid idea"
    end

    test "valid idea with rationale" do
      attrs = %{
        "idea" => "This is a valid idea",
        "rationale" => "This makes sense because..."
      }

      changeset = IdeaResponse.changeset(%IdeaResponse{}, attrs)

      assert changeset.valid?
      assert changeset.changes.idea == "This is a valid idea"
      assert changeset.changes.rationale == "This makes sense because..."
    end

    test "invalid when idea is missing" do
      attrs = %{}
      changeset = IdeaResponse.changeset(%IdeaResponse{}, attrs)

      refute changeset.valid?
      assert {:idea, {"can't be blank", [validation: :required]}} in changeset.errors
    end

    test "invalid when idea is empty string" do
      attrs = %{"idea" => ""}
      changeset = IdeaResponse.changeset(%IdeaResponse{}, attrs)

      refute changeset.valid?
      # Empty string gets caught by validate_required first
      assert [idea: {"can't be blank", [validation: :required]}] = changeset.errors
    end

    test "invalid when idea is too long" do
      attrs = %{"idea" => String.duplicate("a", 1024)}
      changeset = IdeaResponse.changeset(%IdeaResponse{}, attrs)

      refute changeset.valid?

      assert [
               idea:
                 {"should be at most %{count} character(s)",
                  [count: 1023, validation: :length, kind: :max, type: :string]}
             ] = changeset.errors
    end

    test "valid with idea at max length" do
      attrs = %{"idea" => String.duplicate("a", 1023)}
      changeset = IdeaResponse.changeset(%IdeaResponse{}, attrs)

      assert changeset.valid?
    end

    test "valid when rationale is omitted" do
      attrs = %{
        "idea" => "Valid idea"
      }

      changeset = IdeaResponse.changeset(%IdeaResponse{}, attrs)

      # Rationale is optional, so omitting it should be valid
      assert changeset.valid?
    end

    test "valid when rationale is empty string" do
      attrs = %{
        "idea" => "Valid idea",
        "rationale" => ""
      }

      changeset = IdeaResponse.changeset(%IdeaResponse{}, attrs)

      # Empty string for optional field gets cast to nil and is valid
      assert changeset.valid?
      refute Map.has_key?(changeset.changes, :rationale)
    end

    test "invalid when rationale is too long" do
      attrs = %{
        "idea" => "Valid idea",
        "rationale" => String.duplicate("a", 2001)
      }

      changeset = IdeaResponse.changeset(%IdeaResponse{}, attrs)

      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :rationale)
      assert {msg, _} = changeset.errors[:rationale]
      assert msg =~ "should be at most"
    end
  end

  describe "validate_ideas/1" do
    test "validates a list of valid ideas" do
      ideas = [
        %{"idea" => "First idea"},
        %{"idea" => "Second idea"},
        %{"idea" => "Third idea"}
      ]

      assert {:ok, validated} = IdeaResponse.validate_ideas(ideas)
      assert length(validated) == 3
      assert Enum.at(validated, 0).idea == "First idea"
      assert Enum.at(validated, 1).idea == "Second idea"
      assert Enum.at(validated, 2).idea == "Third idea"
    end

    test "validates ideas with rationale" do
      ideas = [
        %{"idea" => "First idea", "rationale" => "Because reasons"},
        %{"idea" => "Second idea"}
      ]

      assert {:ok, validated} = IdeaResponse.validate_ideas(ideas)
      assert length(validated) == 2
      assert Enum.at(validated, 0).idea == "First idea"
      assert Enum.at(validated, 0).rationale == "Because reasons"
      assert Enum.at(validated, 1).idea == "Second idea"
      assert Enum.at(validated, 1).rationale == nil
    end

    test "returns error for invalid idea in list" do
      ideas = [
        %{"idea" => "Valid idea"},
        %{"idea" => ""},
        %{"idea" => "Another valid idea"}
      ]

      assert {:error, errors} = IdeaResponse.validate_ideas(ideas)
      assert is_map(errors)
      assert Map.has_key?(errors, 1)
      assert Map.get(errors, 1).idea
    end

    test "returns error for missing idea field" do
      ideas = [
        %{"idea" => "Valid idea"},
        %{"rationale" => "No idea field"}
      ]

      assert {:error, errors} = IdeaResponse.validate_ideas(ideas)
      assert is_map(errors)
      assert Map.has_key?(errors, 1)
      assert ["can't be blank"] = Map.get(errors, 1).idea
    end

    test "returns error when input is not a list" do
      assert {:error, %{base: ["expected a list of ideas"]}} =
               IdeaResponse.validate_ideas(%{"idea" => "Not a list"})
    end

    test "returns error when input is nil" do
      assert {:error, %{base: ["expected a list of ideas"]}} = IdeaResponse.validate_ideas(nil)
    end

    test "validates empty list successfully" do
      assert {:ok, []} = IdeaResponse.validate_ideas([])
    end

    test "returns error with index for idea too long" do
      ideas = [
        %{"idea" => "Valid idea"},
        %{"idea" => String.duplicate("a", 1024)}
      ]

      assert {:error, errors} = IdeaResponse.validate_ideas(ideas)
      assert Map.has_key?(errors, 1)
      assert ["should be at most 1023 character(s)"] = Map.get(errors, 1).idea
    end

    test "returns error with index for rationale too long" do
      ideas = [
        %{"idea" => "Valid idea"},
        %{"idea" => "Another idea", "rationale" => String.duplicate("a", 2001)}
      ]

      assert {:error, errors} = IdeaResponse.validate_ideas(ideas)
      assert Map.has_key?(errors, 1)
      assert ["should be at most 2000 character(s)"] = Map.get(errors, 1).rationale
    end

    test "stops validation at first error" do
      ideas = [
        %{"idea" => "Valid idea"},
        %{"idea" => ""},
        %{"idea" => String.duplicate("a", 1024)}
      ]

      # Should fail at index 1 and not continue to index 2
      assert {:error, errors} = IdeaResponse.validate_ideas(ideas)
      assert map_size(errors) == 1
      assert Map.has_key?(errors, 1)
    end
  end
end
