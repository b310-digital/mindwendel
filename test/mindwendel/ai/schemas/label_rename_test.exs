defmodule Mindwendel.AI.Schemas.LabelRenameTest do
  use ExUnit.Case, async: true

  alias Mindwendel.AI.Schemas.LabelRename

  describe "cast_label_renames/1" do
    test "returns sanitized rename entries when payload is valid" do
      id = Ecto.UUID.generate()

      payload = [
        %{"id" => id, "name" => "Fresh Spark"}
      ]

      assert {:ok, [%{id: ^id, name: "Fresh Spark"}]} = LabelRename.cast_label_renames(payload)
    end

    test "rejects names longer than 15 characters" do
      id = Ecto.UUID.generate()

      payload = [
        %{"id" => id, "name" => "This name is far too long"}
      ]

      assert {:error, %{0 => %{base: ["invalid label rename data"]}}} =
               LabelRename.cast_label_renames(payload)
    end

    test "rejects names with more than two words" do
      id = Ecto.UUID.generate()

      payload = [
        %{"id" => id, "name" => "Three word title"}
      ]

      assert {:error, %{0 => %{base: ["invalid label rename data"]}}} =
               LabelRename.cast_label_renames(payload)
    end

    test "rejects invalid UUIDs" do
      payload = [
        %{"id" => "not-a-uuid", "name" => "Valid Name"}
      ]

      assert {:error, %{0 => %{base: ["invalid label rename data"]}}} =
               LabelRename.cast_label_renames(payload)
    end

    test "rejects non-list payloads" do
      assert {:error, %{base: ["expected a list of label rename entries"]}} =
               LabelRename.cast_label_renames(%{})
    end
  end
end
