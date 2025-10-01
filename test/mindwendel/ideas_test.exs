defmodule Mindwendel.IdeasTest do
  use Mindwendel.DataCase, async: true
  alias Mindwendel.Factory

  alias Mindwendel.Ideas
  alias Mindwendel.Brainstormings.Idea

  setup do
    user = Factory.insert!(:user)
    brainstorming = Factory.insert!(:brainstorming, users: [user])
    lane = List.first(brainstorming.lanes)
    label_first = List.first(brainstorming.labels)

    %{
      brainstorming: brainstorming,
      idea:
        Factory.insert!(:idea,
          body: "first idea",
          brainstorming: brainstorming,
          lane: lane,
          inserted_at: ~N[2021-01-01 15:04:30],
          updated_at: ~N[2021-01-01 15:04:30],
          position_order: 1
        ),
      user: user,
      like: Factory.insert!(:like, :with_idea_and_user),
      lane: lane,
      label: label_first
    }
  end

  describe "increment_comment_count" do
    test "increments comment count on an idea",
         %{
           idea: idea
         } do
      {:ok, idea} = Ideas.increment_comment_count(idea.id)
      assert idea.comments_count == 1
    end
  end

  describe "decrements_comment_count" do
    test "increments comment count on an idea",
         %{
           idea: idea
         } do
      Ideas.update_idea(idea, %{comments_count: 1})
      {:ok, idea} = Ideas.decrement_comment_count(idea.id)
      assert idea.comments_count == 0
    end
  end

  describe "get_max_position_order" do
    test "returns 0 if no position is available",
         %{
           brainstorming: brainstorming,
           label: label
         } do
      assert Ideas.get_max_position_order(brainstorming.id, %{
               labels_ids: [
                 label.id
               ]
             }) == 0
    end

    test "returns 1 if one idea is present with pos order of 1",
         %{
           brainstorming: brainstorming,
           label: label,
           lane: lane
         } do
      Factory.insert!(:idea,
        brainstorming: brainstorming,
        position_order: 1,
        lane: lane,
        idea_labels: [label],
        updated_at: ~N[2021-01-03 15:04:30],
        inserted_at: ~N[2021-01-01 15:04:30]
      )

      assert Ideas.get_max_position_order(brainstorming.id, %{
               labels_ids: [
                 label.id
               ]
             }) == 1
    end

    test "returns the pos number of the matching idea if only one idea is matching the label",
         %{
           brainstorming: brainstorming,
           label: label,
           lane: lane
         } do
      filter_label = Enum.at(brainstorming.labels, 1)

      Factory.insert!(:idea,
        brainstorming: brainstorming,
        position_order: 1,
        lane: lane,
        idea_labels: [filter_label],
        updated_at: ~N[2021-01-03 15:04:30],
        inserted_at: ~N[2021-01-01 15:04:30]
      )

      Factory.insert!(:idea,
        brainstorming: brainstorming,
        position_order: 2,
        lane: lane,
        idea_labels: [label],
        updated_at: ~N[2021-01-03 15:04:30],
        inserted_at: ~N[2021-01-01 15:04:30]
      )

      assert Ideas.get_max_position_order(brainstorming.id, %{
               labels_ids: [
                 filter_label.id
               ]
             }) == 1
    end
  end

  describe "update_disjoint_idea_positions_for_brainstorming_by_labels" do
    test "sorts ideas with given labels first but including ideas without named label at the end",
         %{
           brainstorming: brainstorming,
           idea: idea,
           label: label,
           lane: lane
         } do
      second_idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          position_order: 1,
          lane: lane,
          idea_labels: [label],
          updated_at: ~N[2021-01-03 15:04:30],
          inserted_at: ~N[2021-01-01 15:04:30]
        )

      Ideas.update_disjoint_idea_positions_for_brainstorming_by_labels(brainstorming.id, [
        label.id
      ])

      lanes_with_ideas_sorted_by_position = Ideas.list_ideas_for_brainstorming(brainstorming.id)

      assert Enum.map(lanes_with_ideas_sorted_by_position, & &1.id) == [
               second_idea.id,
               idea.id
             ]
    end

    test "updates positions but keeping relative positioning", %{
      brainstorming: brainstorming,
      idea: idea,
      label: label,
      lane: lane
    } do
      second_idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          position_order: 1,
          lane: lane,
          idea_labels: [label],
          updated_at: ~N[2021-01-03 15:04:30],
          inserted_at: ~N[2021-01-01 15:04:30]
        )

      third_idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          position_order: 2,
          lane: lane,
          idea_labels: [label],
          updated_at: ~N[2021-01-03 15:04:30],
          inserted_at: ~N[2021-01-01 15:04:30]
        )

      Ideas.update_disjoint_idea_positions_for_brainstorming_by_labels(brainstorming.id, [
        label.id
      ])

      lanes_with_ideas_sorted_by_position = Ideas.list_ideas_for_brainstorming(brainstorming.id)

      assert Enum.map(lanes_with_ideas_sorted_by_position, & &1.id) == [
               second_idea.id,
               third_idea.id,
               idea.id
             ]
    end

    test "updates positions preferring given label ids", %{
      brainstorming: brainstorming,
      idea: idea,
      label: label,
      lane: lane
    } do
      Ideas.update_idea(idea, %{idea_label: Enum.at(brainstorming.labels, 1)})

      second_idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          position_order: 1,
          lane: lane,
          idea_labels: [label],
          updated_at: ~N[2021-01-03 15:04:30],
          inserted_at: ~N[2021-01-01 15:04:30]
        )

      third_idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          position_order: 2,
          lane: lane,
          idea_labels: [label],
          updated_at: ~N[2021-01-03 15:04:30],
          inserted_at: ~N[2021-01-01 15:04:30]
        )

      Ideas.update_disjoint_idea_positions_for_brainstorming_by_labels(brainstorming.id, [
        label.id
      ])

      lanes_with_ideas_sorted_by_position = Ideas.list_ideas_for_brainstorming(brainstorming.id)

      assert Enum.map(lanes_with_ideas_sorted_by_position, & &1.id) == [
               second_idea.id,
               third_idea.id,
               idea.id
             ]
    end
  end

  describe "list_ideas_for_brainstorming" do
    test "sorts ideas based on time of insertion if no position is given", %{
      brainstorming: brainstorming,
      lane: lane,
      idea: idea
    } do
      second_idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane,
          updated_at: ~N[2021-01-03 15:04:30],
          inserted_at: ~N[2021-01-01 15:04:30]
        )

      third_idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane,
          updated_at: ~N[2021-01-02 15:04:30],
          inserted_at: ~N[2021-01-02 15:04:30]
        )

      ideas_sorted_by_position = Ideas.list_ideas_for_brainstorming(brainstorming.id)

      assert Enum.map(ideas_sorted_by_position, & &1.id) == [
               idea.id,
               second_idea.id,
               third_idea.id
             ]
    end

    test "sorts ideas based on position", %{
      brainstorming: brainstorming,
      lane: lane,
      idea: idea
    } do
      second_idea =
        Factory.insert!(:idea, brainstorming: brainstorming, lane: lane, position_order: 2)

      third_idea =
        Factory.insert!(:idea, brainstorming: brainstorming, lane: lane, position_order: 3)

      ideas_sorted_by_position = Ideas.list_ideas_for_brainstorming(brainstorming.id)

      assert Enum.map(ideas_sorted_by_position, & &1.id) == [
               idea.id,
               second_idea.id,
               third_idea.id
             ]
    end
  end

  describe "update_ideas_for_brainstorming_by_likes" do
    test "updates the order position for three ideas", %{
      brainstorming: brainstorming,
      idea: idea,
      lane: lane
    } do
      Ideas.update_ideas_for_brainstorming_by_likes(brainstorming.id, lane.id)
      assert Repo.reload(idea).position_order == 1
    end

    test "update ideas in the correct order", %{
      brainstorming: brainstorming,
      lane: lane,
      user: user,
      idea: idea
    } do
      Factory.insert!(:like, idea: idea, user: user, inserted_at: ~N[2021-01-01 15:04:30])
      another_user = Factory.insert!(:user)
      Factory.insert!(:like, idea: idea, user: another_user, inserted_at: ~N[2021-01-01 15:06:30])
      second_idea = Factory.insert!(:idea, brainstorming: brainstorming, lane: lane)

      Factory.insert!(:like,
        idea: second_idea,
        user: another_user,
        inserted_at: ~N[2021-01-01 15:06:32]
      )

      third_idea = Factory.insert!(:idea, brainstorming: brainstorming, lane: lane)
      Ideas.update_ideas_for_brainstorming_by_likes(brainstorming.id, lane.id)

      query =
        from(idea in Idea,
          where: idea.brainstorming_id == ^brainstorming.id,
          order_by: [asc_nulls_last: idea.position_order]
        )

      ideas_sorted_by_position = Repo.all(query)

      assert ideas_sorted_by_position |> Enum.map(& &1.id) == [
               idea.id,
               second_idea.id,
               third_idea.id
             ]
    end
  end

  describe "update_ideas_for_brainstorming_by_labels" do
    test "updates the order position for three ideas", %{
      brainstorming: brainstorming,
      idea: idea,
      lane: lane
    } do
      Ideas.update_ideas_for_brainstorming_by_labels(brainstorming.id, lane.id)
      assert Repo.reload(idea).position_order == 1
    end

    test "update ideas in the correct order", %{
      brainstorming: brainstorming,
      lane: lane,
      idea: idea
    } do
      [first_label, second_label | _] = brainstorming.labels

      second_idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane,
          idea_labels: [first_label],
          inserted_at: ~N[2022-01-01 15:06:30]
        )

      third_idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane,
          idea_labels: [second_label],
          inserted_at: ~N[2021-01-01 15:06:30]
        )

      Ideas.update_ideas_for_brainstorming_by_labels(brainstorming.id, lane.id)
      ideas_sorted_by_position = Ideas.list_ideas_for_brainstorming(brainstorming.id)

      assert ideas_sorted_by_position |> Enum.map(& &1.id) == [
               second_idea.id,
               third_idea.id,
               idea.id
             ]
    end
  end

  describe "update_ideas_for_brainstorming_by_user_move" do
    test "update idea to the first position", %{
      brainstorming: brainstorming,
      idea: idea,
      lane: lane
    } do
      second_idea =
        Factory.insert!(:idea,
          body: "second",
          brainstorming: brainstorming,
          lane: lane,
          position_order: 2,
          updated_at: ~N[2021-01-01 15:06:30]
        )

      third_idea =
        Factory.insert!(:idea,
          body: "third",
          brainstorming: brainstorming,
          lane: lane,
          position_order: 3,
          updated_at: ~N[2021-01-01 15:06:30]
        )

      Ideas.update_ideas_for_brainstorming_by_user_move(
        brainstorming.id,
        lane.id,
        third_idea.id,
        1,
        3
      )

      query =
        from(idea in Idea,
          where: idea.brainstorming_id == ^brainstorming.id and idea.lane_id == ^lane.id,
          order_by: [asc_nulls_last: idea.position_order]
        )

      ideas_sorted_by_position = Repo.all(query)

      assert ideas_sorted_by_position |> Enum.map(& &1.id) == [
               third_idea.id,
               idea.id,
               second_idea.id
             ]
    end
  end

  test "update idea to the last position", %{
    brainstorming: brainstorming,
    idea: idea,
    lane: lane
  } do
    second_idea =
      Factory.insert!(:idea,
        body: "second",
        brainstorming: brainstorming,
        lane: lane,
        position_order: 2,
        updated_at: ~N[2021-01-01 15:06:30]
      )

    third_idea =
      Factory.insert!(:idea,
        body: "third",
        brainstorming: brainstorming,
        lane: lane,
        position_order: 3,
        updated_at: ~N[2021-01-01 15:06:30]
      )

    Ideas.update_ideas_for_brainstorming_by_user_move(brainstorming.id, lane.id, idea.id, 3, 1)

    query =
      from(idea in Idea,
        where: idea.brainstorming_id == ^brainstorming.id and idea.lane_id == ^lane.id,
        order_by: [asc_nulls_last: idea.position_order]
      )

    ideas_sorted_by_position = Repo.all(query)

    assert ideas_sorted_by_position |> Enum.map(& &1.id) == [
             second_idea.id,
             third_idea.id,
             idea.id
           ]
  end

  describe "create_idea with HTML stripping" do
    test "strips HTML tags when creating an idea", %{brainstorming: brainstorming, lane: lane} do
      {:ok, idea} =
        Ideas.create_idea(%{
          body: "<script>alert('XSS')</script>Clean text",
          brainstorming_id: brainstorming.id,
          lane_id: lane.id,
          username: "TestUser"
        })

      # Verify HTML was stripped before saving
      assert idea.body == "Clean text"

      # Verify the stripped value is persisted in the database
      reloaded_idea = Repo.get!(Idea, idea.id)
      assert reloaded_idea.body == "Clean text"
    end

    test "strips complex HTML when creating an idea", %{brainstorming: brainstorming, lane: lane} do
      {:ok, idea} =
        Ideas.create_idea(%{
          body: "<div><p>Paragraph 1</p><p>Paragraph 2</p></div>",
          brainstorming_id: brainstorming.id,
          lane_id: lane.id,
          username: "TestUser"
        })

      assert idea.body == "Paragraph 1 Paragraph 2"
    end

    test "fails validation when body becomes empty after stripping", %{
      brainstorming: brainstorming,
      lane: lane
    } do
      {:error, changeset} =
        Ideas.create_idea(%{
          body: "<script>alert('XSS')</script>",
          brainstorming_id: brainstorming.id,
          lane_id: lane.id,
          username: "TestUser"
        })

      refute changeset.valid?
    end
  end

  describe "update_idea with HTML stripping" do
    test "strips HTML tags when updating an idea", %{idea: idea} do
      {:ok, updated_idea} = Ideas.update_idea(idea, %{body: "<b>Bold</b> updated text"})

      assert updated_idea.body == "Bold updated text"

      # Verify the stripped value is persisted in the database
      reloaded_idea = Repo.get!(Idea, idea.id)
      assert reloaded_idea.body == "Bold updated text"
    end
  end
end
