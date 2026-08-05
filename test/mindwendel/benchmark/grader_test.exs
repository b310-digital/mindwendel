defmodule Mindwendel.Benchmark.GraderTest do
  use ExUnit.Case, async: true

  alias Mindwendel.Benchmark.Grader

  describe "grade_json_validity/1" do
    test "returns score 0.0 for nil input" do
      result = Grader.grade_json_validity(nil)
      assert result.score == 0.0
    end

    test "includes descriptive weakness message for nil input" do
      result = Grader.grade_json_validity(nil)
      assert result.weaknesses =~ "No output"
    end

    test "returns score 0.0 for invalid JSON" do
      result = Grader.grade_json_validity("not json at all")
      assert result.score == 0.0
      assert result.weaknesses =~ "JSON decode failed"
    end

    test "returns score 0.0 when top-level is not a list" do
      result = Grader.grade_json_validity(~s({"idea": "oops"}))
      assert result.score == 0.0
      assert result.weaknesses =~ "Expected a JSON array"
    end

    test "returns score 0.0 for empty array" do
      result = Grader.grade_json_validity("[]")
      assert result.score == 0.0
      assert result.weaknesses =~ "empty array"
    end

    test "returns 10.0 for a valid list of ideas" do
      raw =
        Jason.encode!([
          %{"idea" => "Chlorophyll"},
          %{"idea" => "Sunlight absorption"},
          %{"idea" => "Carbon dioxide conversion"},
          %{"idea" => "Oxygen release"},
          %{"idea" => "Glucose production"}
        ])

      assert Grader.grade_json_validity(raw).score == 10.0
    end

    test "sets strengths and no weaknesses for a fully valid list" do
      raw = Jason.encode!([%{"idea" => "A"}, %{"idea" => "B"}])
      result = Grader.grade_json_validity(raw)
      assert result.strengths =~ "2/2"
      assert is_nil(result.weaknesses)
    end

    test "returns proportional score when some ideas fail validation" do
      raw =
        Jason.encode!([%{"idea" => "Valid idea"}, %{}, %{"idea" => "Another valid idea"}, %{}])

      assert Grader.grade_json_validity(raw).score == 5.0
    end

    test "includes failure index in weaknesses for invalid ideas" do
      raw = Jason.encode!([%{"idea" => "Valid"}, %{}])
      assert Grader.grade_json_validity(raw).weaknesses =~ "idea[1]"
    end

    test "strips markdown code fences before parsing" do
      raw = "```json\n[{\"idea\": \"Photosynthesis basics\"}]\n```"
      result = Grader.grade_json_validity(raw)
      assert result.score == 10.0
    end

    test "returns 0.0 when idea text exceeds max length" do
      too_long = String.duplicate("x", 1024)
      raw = Jason.encode!([%{"idea" => too_long}])
      result = Grader.grade_json_validity(raw)
      assert result.score == 0.0
    end
  end

  describe "grade_duration/1" do
    test "returns 10.0 for response at exactly the target (5000ms)" do
      assert Grader.grade_duration(5000).score == 10.0
    end

    test "returns 10.0 for response well under target" do
      assert Grader.grade_duration(1000).score == 10.0
    end

    test "returns 10.0 for 0ms" do
      assert Grader.grade_duration(0).score == 10.0
    end

    test "loses 1 point per second above target" do
      assert Grader.grade_duration(7000).score == 8.0
      assert Grader.grade_duration(10_000).score == 5.0
    end

    test "floors at 0.0 for very slow responses" do
      assert Grader.grade_duration(20_000).score == 0.0
    end

    test "sets strengths message for fast responses" do
      result = Grader.grade_duration(3000)
      assert result.strengths =~ "3000ms"
      assert is_nil(result.weaknesses)
    end

    test "sets weaknesses message for slow responses" do
      result = Grader.grade_duration(12_000)
      assert result.weaknesses =~ "12000ms"
      assert is_nil(result.strengths)
    end

    test "dimension name is speed" do
      assert Grader.grade_duration(1000).name == "speed"
    end
  end
end
