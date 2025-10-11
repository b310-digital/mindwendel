defmodule Mindwendel.Services.IdeaClusteringServiceTest do
  use Mindwendel.DataCase, async: true
  use Mindwendel.ChatCompletionsCase, async: true

  import Ecto.Query

  alias Mindwendel.Brainstormings
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Brainstormings.IdeaLabel
  alias Mindwendel.BrainstormingsFixtures
  alias Mindwendel.Ideas
  alias Mindwendel.Repo
  alias Mindwendel.Services.IdeaClusteringService

  setup do
    brainstorming = BrainstormingsFixtures.brainstorming_fixture()
    {:ok, reloaded} = Brainstormings.get_brainstorming(brainstorming.id)
    [lane | _] = reloaded.lanes
    [label | _] = reloaded.labels

    {:ok, idea} =
      Ideas.create_idea(%{
        username: "Existing",
        body: "Existing idea to cluster",
        brainstorming_id: reloaded.id,
        lane_id: lane.id
      })

    %{
      brainstorming: reloaded,
      lane: lane,
      label: label,
      idea: Repo.preload(idea, :idea_labels)
    }
  end

  describe "cluster_labels/1" do
    test "returns assignments and persists label changes", %{
      brainstorming: brainstorming,
      label: label,
      idea: idea
    } do
      Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
      |> stub(:enabled?, fn -> true end)
      |> expect(:classify_labels, fn _title, _labels, ideas_payload, _locale ->
        assert Enum.any?(ideas_payload, fn payload -> payload.id == idea.id end)

        {:ok,
         Enum.map(ideas_payload, fn payload ->
           %{
             "idea_id" => payload.id,
             "label_ids" => [label.id]
           }
         end)}
      end)

      assert {:ok, assignments} = IdeaClusteringService.cluster_labels(brainstorming)
      assert [%{idea_id: matched_idea_id, label_ids: matched_label_ids} | _] = assignments
      assert matched_idea_id == idea.id
      assert matched_label_ids == [label.id]

      updated_idea =
        Repo.one!(
          from i in Idea,
            where: i.id == ^idea.id,
            preload: [:idea_labels]
        )

      assert Enum.any?(updated_idea.idea_labels, fn assoc -> assoc.id == label.id end)
    end

    test "skips when AI is disabled", %{brainstorming: brainstorming} do
      disable_ai()
      assert {:ok, :skipped} = IdeaClusteringService.cluster_labels(brainstorming)
    end

    test "attaches existing labels referenced through new label ids", %{
      brainstorming: brainstorming,
      label: label,
      idea: idea
    } do
      Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
      |> stub(:enabled?, fn -> true end)
      |> expect(:classify_labels, fn _title, _labels, ideas_payload, _locale ->
        assert Enum.any?(ideas_payload, fn payload -> payload.id == idea.id end)

        {:ok,
         [
           %{
             "idea_id" => idea.id,
             "label_ids" => [],
             "new_labels" => [
               %{"id" => label.id, "name" => label.name}
             ]
           }
         ]}
      end)

      assert {:ok, [%{label_ids: label_ids}]} =
               IdeaClusteringService.cluster_labels(brainstorming)

      assert label.id in label_ids

      reloaded_idea =
        Repo.one!(
          from i in Idea,
            where: i.id == ^idea.id,
            preload: [:idea_labels]
        )

      assert Enum.any?(reloaded_idea.idea_labels, fn assoc -> assoc.id == label.id end)
    end

    test "ignores suggestions that lack an existing label id", %{
      brainstorming: brainstorming,
      idea: idea
    } do
      Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
      |> stub(:enabled?, fn -> true end)
      |> expect(:classify_labels, fn _title, _labels, ideas_payload, _locale ->
        assert Enum.any?(ideas_payload, fn payload -> payload.id == idea.id end)

        {:ok,
         [
           %{
             "idea_id" => idea.id,
             "label_ids" => [],
             "new_labels" => [
               %{"name" => "Bird Label"}
             ]
           }
         ]}
      end)

      assert {:ok, [%{idea_id: returned_id, label_ids: label_ids}]} =
               IdeaClusteringService.cluster_labels(brainstorming)

      assert returned_id == idea.id
      assert label_ids == []

      labels_after =
        Repo.all(
          from l in IdeaLabel,
            where: l.brainstorming_id == ^brainstorming.id
        )

      assert length(labels_after) == length(brainstorming.labels)
    end

    test "renames existing labels when suggestions target their ids", %{
      brainstorming: brainstorming,
      idea: idea
    } do
      sorted_labels =
        brainstorming.labels
        |> Enum.sort_by(&(&1.position_order || 0))

      existing_ids =
        sorted_labels
        |> Enum.map(& &1.id)
        |> Enum.sort()

      new_label_names =
        sorted_labels
        |> Enum.with_index(1)
        |> Enum.map(fn {_label, index} -> "Renamed #{index}" end)

      Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
      |> stub(:enabled?, fn -> true end)
      |> expect(:classify_labels, fn _title, _labels, ideas_payload, _locale ->
        assert Enum.any?(ideas_payload, fn payload -> payload.id == idea.id end)

        {:ok,
         [
           %{
             "idea_id" => idea.id,
             "label_ids" => [],
             "new_labels" =>
               Enum.map(Enum.zip(sorted_labels, new_label_names), fn {label, name} ->
                 %{"id" => label.id, "name" => name}
               end)
           }
         ]}
      end)

      assert {:ok, [%{label_ids: assigned_ids}]} =
               IdeaClusteringService.cluster_labels(brainstorming)

      assert Enum.sort(assigned_ids) == existing_ids

      reloaded_labels =
        Repo.all(
          from l in IdeaLabel,
            where: l.brainstorming_id == ^brainstorming.id,
            order_by: [asc: l.position_order, asc: l.inserted_at]
        )

      assert Enum.map(reloaded_labels, & &1.id) |> Enum.sort() == existing_ids
      assert Enum.map(reloaded_labels, & &1.name) == new_label_names
    end

    test "propagates classification errors", %{brainstorming: brainstorming} do
      Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
      |> stub(:enabled?, fn -> true end)
      |> expect(:classify_labels, fn _title, _labels, _ideas_payload, _locale ->
        {:error, :invalid_response}
      end)

      assert {:error, :invalid_response} = IdeaClusteringService.cluster_labels(brainstorming)
    end
  end
end
