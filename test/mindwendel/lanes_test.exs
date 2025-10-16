defmodule Mindwendel.LanesTest do
  use Mindwendel.DataCase, async: true

  alias Mindwendel.Attachments
  alias Mindwendel.Brainstormings.Lane
  alias Mindwendel.Factory
  alias Mindwendel.Lanes
  import Mindwendel.BrainstormingsFixtures
  import Mindwendel.LanesFixtures

  setup do
    label = Factory.insert!(:idea_label)

    brainstorming =
      Factory.insert!(:brainstorming, labels: [label], filter_labels_ids: [label.id])

    lane = Enum.at(brainstorming.lanes, 0)

    %{brainstorming: brainstorming, lane: lane, label: label}
  end

  test "get_lane!/1 returns the lane with given id" do
    lane =
      lane_fixture()
      |> Repo.preload(
        ideas: [
          :link,
          :likes,
          :label,
          :idea_labels
        ]
      )

    assert Lanes.get_lane!(lane.id) == lane
  end

  test "get_lanes_for_brainstorming_with_labels_filtered/1 returns the lanes with filtered ideas",
       %{
         brainstorming: brainstorming,
         label: label,
         lane: lane
       } do
    idea_with_label =
      Factory.insert!(:idea,
        brainstorming: brainstorming,
        lane: lane,
        idea_labels: [label],
        inserted_at: ~N[2021-01-01 15:04:30],
        position_order: nil
      )

    Factory.insert!(:idea,
      brainstorming: brainstorming,
      lane: lane,
      inserted_at: ~N[2021-01-01 15:04:32],
      position_order: nil
    )

    lanes = Lanes.get_lanes_for_brainstorming_with_labels_filtered(brainstorming.id)

    assert Enum.map(List.first(lanes).ideas, & &1.id) == [
             idea_with_label.id
           ]
  end

  describe "get_lanes_for_brainstorming" do
    test "returns the lanes for the brainstorming id without a filter given", %{
      brainstorming: brainstorming,
      lane: lane
    } do
      idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane,
          inserted_at: ~N[2021-01-01 15:04:30],
          position_order: nil
        )

      second_idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane,
          inserted_at: ~N[2021-01-01 15:04:32],
          position_order: nil
        )

      lanes = Lanes.get_lanes_for_brainstorming(brainstorming.id)

      assert Enum.map(List.first(lanes).ideas, & &1.id) == [
               idea.id,
               second_idea.id
             ]
    end

    test "returns the lanes with filtered ideas", %{
      brainstorming: brainstorming,
      label: label,
      lane: lane
    } do
      idea_with_label =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane,
          idea_labels: [label],
          inserted_at: ~N[2021-01-01 15:04:30],
          position_order: nil
        )

      Factory.insert!(:idea,
        brainstorming: brainstorming,
        lane: lane,
        inserted_at: ~N[2021-01-01 15:04:32],
        position_order: nil
      )

      lanes =
        Lanes.get_lanes_for_brainstorming(brainstorming.id, %{filter_labels_ids: [label.id]})

      assert Enum.map(List.first(lanes).ideas, & &1.id) == [
               idea_with_label.id
             ]
    end
  end

  test "get_max_position_order/1 with valid data" do
    lane = lane_fixture(%{position_order: 10})

    assert Lanes.get_max_position_order(lane.brainstorming_id) == 10
  end

  test "create_lane/1 with valid data creates a lane" do
    valid_attrs = %{
      name: "some name",
      position_order: 42,
      brainstorming_id: brainstorming_fixture().id
    }

    assert {:ok, %Lane{} = lane} = Lanes.create_lane(valid_attrs)
    assert lane.name == "some name"
    assert lane.position_order == 42
  end

  test "update_lane/2 with valid data updates the lane" do
    lane = lane_fixture()
    update_attrs = %{name: "some updated name", position_order: 43}

    assert {:ok, updated_lane} = Lanes.update_lane(lane, update_attrs)
    assert updated_lane.id == lane.id
    assert updated_lane.name == "some updated name"
    assert updated_lane.position_order == 43
  end

  test "delete_lane/1 deletes the lane" do
    lane = lane_fixture()
    assert {:ok, %Lane{}} = Lanes.delete_lane(lane)
    assert_raise Ecto.NoResultsError, fn -> Lanes.get_lane!(lane.id) end
  end

  test "delete_lane/1 deletes ideas and attachments" do
    lane = lane_fixture()

    idea =
      Factory.insert!(:idea,
        lane: lane,
        inserted_at: ~N[2021-01-01 15:04:30]
      )

    file_path = Path.join("priv/static/uploads", "lane_test")
    # create a test file which is used as an attachment
    File.write(file_path, "test")

    attachment = Factory.insert!(:file, idea: idea, path: "uploads/lane_test")
    Lanes.delete_lane(lane)
    refute File.exists?(file_path)
    refute Repo.exists?(from(file in Attachments.File, where: file.id == ^attachment.id))
  end

  test "change_lane/1 returns a lane changeset" do
    lane = lane_fixture()
    assert %Ecto.Changeset{} = Lanes.change_lane(lane)
  end
end
