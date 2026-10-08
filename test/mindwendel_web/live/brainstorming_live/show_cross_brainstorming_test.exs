defmodule MindwendelWeb.BrainstormingLive.ShowCrossBrainstormingTest do
  @moduledoc """
  Records (lanes, ideas, comments, attachments) must only be reachable through
  the brainstorming they belong to. Being moderator of your own brainstorming
  must not grant moderator rights on records of another brainstorming.
  """
  use MindwendelWeb.ConnCase, async: true
  use Mindwendel.ChatCompletionsCase, async: true
  import Phoenix.LiveViewTest

  alias Mindwendel.Accounts
  alias Mindwendel.Attachments
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Brainstormings.Lane
  alias Mindwendel.Comments
  alias Mindwendel.Factory
  alias Mindwendel.Repo

  setup %{conn: conn} do
    disable_ai()

    # The user moderates their own brainstorming ...
    moderating_user = Factory.insert!(:user)
    own_brainstorming = Factory.insert!(:brainstorming)
    Accounts.add_moderating_user(own_brainstorming, moderating_user)
    own_lane = Enum.at(own_brainstorming.lanes, 0)

    own_idea =
      Factory.insert!(:idea,
        brainstorming: own_brainstorming,
        lane: own_lane,
        user_id: moderating_user.id,
        position_order: 1
      )

    # ... and knows the ids of records of another brainstorming they do not moderate
    other_user = Factory.insert!(:user)
    other_brainstorming = Factory.insert!(:brainstorming)
    other_lane = Enum.at(other_brainstorming.lanes, 0)

    other_idea =
      Factory.insert!(:idea,
        body: "original idea",
        brainstorming: other_brainstorming,
        lane: other_lane,
        user_id: other_user.id,
        position_order: 1
      )

    %{
      conn: init_test_session(conn, %{current_user_id: moderating_user.id}),
      moderating_user: moderating_user,
      other_user: other_user,
      own_brainstorming: own_brainstorming,
      own_lane: own_lane,
      own_idea: own_idea,
      other_brainstorming: other_brainstorming,
      other_lane: other_lane,
      other_idea: other_idea
    }
  end

  describe "lanes" do
    test "edit page of a lane of another brainstorming is not found", %{
      conn: conn,
      own_brainstorming: own_brainstorming,
      other_lane: other_lane
    } do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/brainstormings/#{own_brainstorming}/lanes/#{other_lane.id}/edit")
      end
    end

    test "saving the own lane form with the id of another lane does not modify that lane", %{
      conn: conn,
      own_brainstorming: own_brainstorming,
      own_lane: own_lane,
      other_brainstorming: other_brainstorming,
      other_lane: other_lane
    } do
      {:ok, view, _html} =
        live(conn, ~p"/brainstormings/#{own_brainstorming}/lanes/#{own_lane.id}/edit")

      view
      |> form("#label-form")
      |> render_submit(%{
        lane: %{
          id: other_lane.id,
          brainstorming_id: own_brainstorming.id,
          name: "changed content"
        }
      })

      other_lane = Repo.reload!(other_lane)
      assert other_lane.brainstorming_id == other_brainstorming.id
      refute other_lane.name == "changed content"
    end

    test "updating the own lane cannot move it into another brainstorming", %{
      conn: conn,
      own_brainstorming: own_brainstorming,
      own_lane: own_lane,
      other_brainstorming: other_brainstorming
    } do
      {:ok, view, _html} =
        live(conn, ~p"/brainstormings/#{own_brainstorming}/lanes/#{own_lane.id}/edit")

      view
      |> form("#label-form")
      |> render_submit(%{lane: %{brainstorming_id: other_brainstorming.id, name: "renamed"}})

      own_lane = Repo.reload!(own_lane)
      assert own_lane.name == "renamed"
      assert own_lane.brainstorming_id == own_brainstorming.id
    end

    test "creating a lane cannot target another brainstorming", %{
      conn: conn,
      own_brainstorming: own_brainstorming,
      other_brainstorming: other_brainstorming
    } do
      {:ok, view, _html} = live(conn, ~p"/brainstormings/#{own_brainstorming}/new_lane")

      view
      |> form("#label-form")
      |> render_submit(%{lane: %{brainstorming_id: other_brainstorming.id, name: "new lane"}})

      refute Repo.get_by(Lane, brainstorming_id: other_brainstorming.id, name: "new lane")
      assert Repo.get_by(Lane, brainstorming_id: own_brainstorming.id, name: "new lane")
    end
  end

  describe "ideas" do
    test "edit page of an idea of another brainstorming is not found", %{
      conn: conn,
      own_brainstorming: own_brainstorming,
      other_idea: other_idea
    } do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/brainstormings/#{own_brainstorming}/ideas/#{other_idea.id}/edit")
      end
    end

    test "show page of an idea of another brainstorming is not found", %{
      conn: conn,
      own_brainstorming: own_brainstorming,
      other_idea: other_idea
    } do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/brainstormings/#{own_brainstorming}/ideas/#{other_idea.id}")
      end
    end

    test "new idea page with a lane of another brainstorming is not found", %{
      conn: conn,
      own_brainstorming: own_brainstorming,
      other_lane: other_lane
    } do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/brainstormings/#{own_brainstorming}/lanes/#{other_lane.id}/new_idea")
      end
    end

    test "saving the own idea form with the id of another idea does not modify that idea", %{
      conn: conn,
      own_brainstorming: own_brainstorming,
      own_idea: own_idea,
      other_idea: other_idea
    } do
      {:ok, view, _html} =
        live(conn, ~p"/brainstormings/#{own_brainstorming}/ideas/#{own_idea.id}/edit")

      view
      |> form("#idea-form")
      |> render_submit(%{
        idea: %{id: other_idea.id, body: "changed content", username: "changed content"}
      })

      assert Repo.reload!(other_idea).body == "original idea"
    end

    test "updating the own idea cannot move it into another brainstorming or lane", %{
      conn: conn,
      own_brainstorming: own_brainstorming,
      own_lane: own_lane,
      own_idea: own_idea,
      other_brainstorming: other_brainstorming,
      other_lane: other_lane
    } do
      {:ok, view, _html} =
        live(conn, ~p"/brainstormings/#{own_brainstorming}/ideas/#{own_idea.id}/edit")

      view
      |> form("#idea-form")
      |> render_submit(%{
        idea: %{
          body: "moved?",
          brainstorming_id: other_brainstorming.id,
          lane_id: other_lane.id
        }
      })

      own_idea = Repo.reload!(own_idea)
      assert own_idea.brainstorming_id == own_brainstorming.id
      assert own_idea.lane_id == own_lane.id
    end

    test "updating the own idea cannot change its comments count or position", %{
      conn: conn,
      own_brainstorming: own_brainstorming,
      own_idea: own_idea
    } do
      own_idea = Repo.reload!(own_idea)

      {:ok, view, _html} =
        live(conn, ~p"/brainstormings/#{own_brainstorming}/ideas/#{own_idea.id}/edit")

      view
      |> form("#idea-form")
      |> render_submit(%{
        idea: %{body: "changed", comments_count: 9999, position_order: -5}
      })

      reloaded_idea = Repo.reload!(own_idea)
      assert reloaded_idea.body == "changed"
      assert reloaded_idea.comments_count == own_idea.comments_count
      assert reloaded_idea.position_order == own_idea.position_order
    end

    test "creating an idea cannot target another brainstorming or lane", %{
      conn: conn,
      own_brainstorming: own_brainstorming,
      own_lane: own_lane,
      other_brainstorming: other_brainstorming,
      other_lane: other_lane
    } do
      {:ok, view, _html} =
        live(conn, ~p"/brainstormings/#{own_brainstorming}/lanes/#{own_lane.id}/new_idea")

      view
      |> form("#idea-form")
      |> render_submit(%{
        idea: %{
          body: "new idea",
          username: "someone",
          brainstorming_id: other_brainstorming.id,
          lane_id: other_lane.id
        }
      })

      refute Repo.get_by(Idea, brainstorming_id: other_brainstorming.id, body: "new idea")

      assert %Idea{lane_id: lane_id} =
               Repo.get_by(Idea, brainstorming_id: own_brainstorming.id, body: "new idea")

      assert lane_id == own_lane.id
    end

    test "creating an idea in a lane deleted in the meantime shows an error", %{
      conn: conn,
      own_brainstorming: own_brainstorming
    } do
      {:ok, lane} = Mindwendel.Lanes.create_lane(%{brainstorming_id: own_brainstorming.id})

      {:ok, view, _html} =
        live(conn, ~p"/brainstormings/#{own_brainstorming}/lanes/#{lane.id}/new_idea")

      {:ok, _} = Mindwendel.Lanes.delete_lane(lane)

      html =
        view
        |> form("#idea-form")
        |> render_submit(%{idea: %{body: "new idea", username: "someone"}})

      assert html =~ "The lane of this idea does not exist anymore"
      refute Repo.get_by(Idea, body: "new idea")
    end
  end

  describe "url" do
    test "patching to a url of another brainstorming loads that brainstorming", %{
      conn: conn,
      own_brainstorming: own_brainstorming,
      other_brainstorming: other_brainstorming,
      other_idea: other_idea
    } do
      {:ok, view, _html} = live(conn, ~p"/brainstormings/#{own_brainstorming}")
      path = ~p"/brainstormings/#{other_brainstorming}/ideas/#{other_idea.id}"

      assert {:error, {:live_redirect, %{to: ^path}}} = render_patch(view, path)
    end
  end

  describe "change_position" do
    test "cannot move an idea of another brainstorming into the own lane", %{
      conn: conn,
      own_brainstorming: own_brainstorming,
      own_lane: own_lane,
      other_lane: other_lane,
      other_idea: other_idea
    } do
      {:ok, view, _html} = live(conn, ~p"/brainstormings/#{own_brainstorming}")

      push_change_position(view, %{
        "id" => other_idea.id,
        "brainstorming_id" => own_brainstorming.id,
        "lane_id" => own_lane.id
      })

      assert Repo.reload!(other_idea).lane_id == other_lane.id
    end

    test "cannot move the own idea into a lane of another brainstorming", %{
      conn: conn,
      own_brainstorming: own_brainstorming,
      own_lane: own_lane,
      own_idea: own_idea,
      other_lane: other_lane
    } do
      {:ok, view, _html} = live(conn, ~p"/brainstormings/#{own_brainstorming}")

      push_change_position(view, %{
        "id" => own_idea.id,
        "brainstorming_id" => own_brainstorming.id,
        "lane_id" => other_lane.id
      })

      assert Repo.reload!(own_idea).lane_id == own_lane.id
    end

    test "ignores the brainstorming_id param and uses the mounted brainstorming", %{
      conn: conn,
      own_brainstorming: own_brainstorming,
      other_brainstorming: other_brainstorming,
      other_lane: other_lane,
      other_idea: other_idea
    } do
      # The other brainstorming allows manual ordering for its participants, but
      # the user is changing the order from the page of their own brainstorming.
      other_brainstorming
      |> Ecto.Changeset.change(option_allow_manual_ordering: true)
      |> Repo.update!()

      second_other_lane =
        Factory.insert!(:lane, brainstorming: other_brainstorming, position_order: 2)

      {:ok, view, _html} = live(conn, ~p"/brainstormings/#{own_brainstorming}")

      push_change_position(view, %{
        "id" => other_idea.id,
        "brainstorming_id" => other_brainstorming.id,
        "lane_id" => second_other_lane.id
      })

      assert Repo.reload!(other_idea).lane_id == other_lane.id
    end

    test "still moves an own idea within the own brainstorming", %{
      conn: conn,
      own_brainstorming: own_brainstorming,
      own_idea: own_idea
    } do
      second_own_lane =
        Factory.insert!(:lane,
          brainstorming: own_brainstorming,
          name: "second",
          position_order: 2
        )

      {:ok, view, _html} = live(conn, ~p"/brainstormings/#{own_brainstorming}")

      # the client no longer sends a brainstorming_id
      push_change_position(view, %{
        "id" => own_idea.id,
        "lane_id" => second_own_lane.id
      })

      assert Repo.reload!(own_idea).lane_id == second_own_lane.id
    end
  end

  describe "labels" do
    test "cannot add a label of another brainstorming to the own idea", %{
      conn: conn,
      own_brainstorming: own_brainstorming,
      own_idea: own_idea,
      other_brainstorming: other_brainstorming
    } do
      own_label = Enum.at(own_brainstorming.labels, 0)
      other_label = Enum.at(other_brainstorming.labels, 0)

      {:ok, view, _html} = live(conn, ~p"/brainstormings/#{own_brainstorming}")

      view
      |> element(
        ".IndexComponent__IdeaCard[data-testid=\"#{own_idea.id}\"] a[data-testid=\"#{own_label.id}\"][phx-click=\"add_idea_label_to_idea\"]"
      )
      |> render_click(%{"idea-label-id" => other_label.id})

      assert Repo.preload(own_idea, :idea_labels, force: true).idea_labels == []
    end
  end

  describe "comments" do
    test "comments of an idea of another brainstorming cannot be modified through the own brainstorming",
         %{
           conn: conn,
           own_brainstorming: own_brainstorming,
           other_user: other_user,
           other_idea: other_idea
         } do
      {:ok, comment} =
        Comments.create_comment(%{
          idea_id: other_idea.id,
          user_id: other_user.id,
          body: "original comment",
          username: "other user"
        })

      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/brainstormings/#{own_brainstorming}/ideas/#{other_idea.id}")
      end

      assert Comments.get_comment!(comment.id).body == "original comment"
    end
  end

  describe "attachments" do
    test "delete_attachment does not delete files of another idea", %{
      conn: conn,
      own_brainstorming: own_brainstorming,
      own_idea: own_idea,
      other_idea: other_idea
    } do
      own_file = Factory.insert!(:file, idea: own_idea, path: "uploads/#{Ecto.UUID.generate()}")

      other_file =
        Factory.insert!(:file, idea: other_idea, path: "uploads/#{Ecto.UUID.generate()}")

      {:ok, view, _html} =
        live(conn, ~p"/brainstormings/#{own_brainstorming}/ideas/#{own_idea.id}/edit")

      view
      |> element("button[phx-value-id='#{own_file.id}']")
      |> render_click(%{"id" => other_file.id})

      assert Attachments.get_attached_file(other_file.id)
    end

    test "delete_attachment still deletes files of the edited idea", %{
      conn: conn,
      own_brainstorming: own_brainstorming,
      own_idea: own_idea
    } do
      own_file = Factory.insert!(:file, idea: own_idea, path: "uploads/#{Ecto.UUID.generate()}")

      {:ok, view, _html} =
        live(conn, ~p"/brainstormings/#{own_brainstorming}/ideas/#{own_idea.id}/edit")

      view
      |> element("button[phx-value-id='#{own_file.id}']")
      |> render_click()

      refute Attachments.get_attached_file(own_file.id)
    end
  end

  defp push_change_position(view, params) do
    # the Sortable hook pushes the event to the lanes LiveComponent
    view
    |> with_target("#lanes-wrapper")
    |> render_hook(
      "change_position",
      Map.merge(%{"new_position" => 1, "old_position" => 1}, params)
    )
  end
end
