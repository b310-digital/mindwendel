defmodule Mindwendel.Benchmark.ClassificationGraderTest do
  use ExUnit.Case, async: true

  alias Mindwendel.Benchmark.ClassificationGrader

  describe "grade_json_validity/1" do
    test "returns score 0.0 with weakness message for nil input" do
      result = ClassificationGrader.grade_json_validity(nil)
      assert result.score == 0.0
      assert result.weaknesses =~ "No output"
    end

    test "returns score 0.0 with weakness message for invalid JSON" do
      result = ClassificationGrader.grade_json_validity("not json at all")
      assert result.score == 0.0
      assert result.weaknesses =~ "JSON decode failed"
    end

    test "returns score 0.0 when top-level is a JSON array, not an object" do
      raw = Jason.encode!([%{"idea_id" => "abc", "label_ids" => []}])
      result = ClassificationGrader.grade_json_validity(raw)
      assert result.score == 0.0
      assert result.weaknesses =~ "Expected a JSON object"
    end

    test "returns score 0.0 when assignments key is missing" do
      assert ClassificationGrader.grade_json_validity(~s({"foo": []})).score == 0.0
    end

    test "includes 'assignments' in weakness when key is missing" do
      result = ClassificationGrader.grade_json_validity(~s({"foo": []}))
      assert result.weaknesses =~ "assignments"
    end

    test "returns score 0.0 for empty assignments array" do
      result = ClassificationGrader.grade_json_validity(~s({"assignments": []}))
      assert result.score == 0.0
      assert result.weaknesses =~ "Empty"
    end

    test "returns 10.0 for a single valid assignment" do
      raw =
        Jason.encode!(%{
          "assignments" => [
            %{
              "idea_id" => "11111111-1111-1111-1111-111111111101",
              "label_ids" => ["aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"]
            }
          ]
        })

      assert ClassificationGrader.grade_json_validity(raw).score == 10.0
    end

    test "returns 10.0 for multiple valid assignments" do
      raw =
        Jason.encode!(%{
          "assignments" => [
            %{
              "idea_id" => "11111111-1111-1111-1111-111111111101",
              "label_ids" => ["aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"]
            },
            %{
              "idea_id" => "11111111-1111-1111-1111-111111111102",
              "label_ids" => ["bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"]
            }
          ]
        })

      assert ClassificationGrader.grade_json_validity(raw).score == 10.0
    end

    test "returns proportional score when some assignments fail validation" do
      raw =
        Jason.encode!(%{
          "assignments" => [
            %{
              "idea_id" => "11111111-1111-1111-1111-111111111101",
              "label_ids" => ["aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"]
            },
            %{},
            %{
              "idea_id" => "11111111-1111-1111-1111-111111111102",
              "label_ids" => ["bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"]
            },
            %{}
          ]
        })

      assert ClassificationGrader.grade_json_validity(raw).score == 5.0
    end

    test "includes failure index in weaknesses for invalid assignments" do
      raw =
        Jason.encode!(%{
          "assignments" => [
            %{
              "idea_id" => "11111111-1111-1111-1111-111111111101",
              "label_ids" => ["aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"]
            },
            %{}
          ]
        })

      assert ClassificationGrader.grade_json_validity(raw).weaknesses =~ "assignment[1]"
    end

    test "strips markdown code fences before parsing" do
      raw =
        "```json\n" <>
          Jason.encode!(%{
            "assignments" => [
              %{
                "idea_id" => "11111111-1111-1111-1111-111111111101",
                "label_ids" => ["aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"]
              }
            ]
          }) <> "\n```"

      assert ClassificationGrader.grade_json_validity(raw).score == 10.0
    end
  end
end
