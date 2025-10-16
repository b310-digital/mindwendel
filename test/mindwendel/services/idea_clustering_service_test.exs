defmodule Mindwendel.Services.IdeaClusteringServiceTest do
  use Mindwendel.DataCase, async: true
  use Mindwendel.ChatCompletionsCase, async: true

  import Ecto.Query

  alias Mindwendel.AI.Schemas.IdeaLabelAssignment
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
    test "returns assignments and persists label selections", %{
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
           %IdeaLabelAssignment{
             idea_id: payload.id,
             label_ids: [label.id]
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

    test "persists assignments returned as JSON string", %{
      brainstorming: brainstorming,
      label: label,
      idea: idea
    } do
      response_payload = ~s|{
        "assignments": [
          {"idea_id": "#{idea.id}", "label_ids": ["#{label.id}"]}
        ]
      }|

      Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
      |> stub(:enabled?, fn -> true end)
      |> expect(:classify_labels, fn _title, _labels, ideas_payload, _locale ->
        assert Enum.any?(ideas_payload, fn payload -> payload.id == idea.id end)
        {:ok, response_payload}
      end)

      assert {:ok, [%{idea_id: matched_idea_id, label_ids: matched_label_ids}]} =
               IdeaClusteringService.cluster_labels(brainstorming)

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

    test "ignores label ids that do not exist in the brainstorming", %{
      brainstorming: brainstorming,
      idea: idea
    } do
      Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
      |> stub(:enabled?, fn -> true end)
      |> expect(:classify_labels, fn _title, _labels, ideas_payload, _locale ->
        assert Enum.any?(ideas_payload, fn payload -> payload.id == idea.id end)

        {:ok,
         [
           %IdeaLabelAssignment{
             idea_id: idea.id,
             label_ids: [Ecto.UUID.generate()]
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

    test "matches label ids regardless of casing", %{
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
           %IdeaLabelAssignment{
             idea_id: String.upcase(idea.id),
             label_ids: [String.upcase(label.id)]
           }
         ]}
      end)

      assert {:ok, [%{idea_id: returned_id, label_ids: [returned_label_id]}]} =
               IdeaClusteringService.cluster_labels(brainstorming)

      assert returned_id == idea.id
      assert returned_label_id == label.id

      updated_idea =
        Repo.one!(
          from i in Idea,
            where: i.id == ^idea.id,
            preload: [:idea_labels]
        )

      assert Enum.any?(updated_idea.idea_labels, fn assoc -> assoc.id == label.id end)
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
