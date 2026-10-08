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
end
