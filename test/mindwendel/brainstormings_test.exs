defmodule Mindwendel.BrainstormingsTest do
  use Mindwendel.DataCase, async: true

  alias Mindwendel.Accounts.User
  alias Mindwendel.Attachments
  alias Mindwendel.Brainstormings
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.Comment
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Brainstormings.IdeaIdeaLabel
  alias Mindwendel.Brainstormings.Like
  alias Mindwendel.Factory
  alias Mindwendel.IdeaLabels
  alias Mindwendel.Lanes

  setup do
    user = Factory.insert!(:user)
    brainstorming = Factory.insert!(:brainstorming, users: [user])

    %{
      brainstorming: brainstorming,
      idea:
        Factory.insert!(:idea, brainstorming: brainstorming, inserted_at: ~N[2021-01-01 15:04:30]),
      user: user,
      like: Factory.insert!(:like, :with_idea_and_user),
      lane: Enum.at(brainstorming.lanes, 0)
    }
  end

  describe "update_last_accessed_at" do
    test "updates the last accessed at field", %{brainstorming: brainstorming} do
      Brainstormings.update_last_accessed_at(brainstorming)
      {:ok, refreshed_brainstorming} = Brainstormings.get_brainstorming(brainstorming.id)
      refute refreshed_brainstorming.last_accessed_at == nil
    end
  end

  describe "update_brainstorming" do
    test "updates the brainstorming with filter_labels_ids", %{brainstorming: brainstorming} do
      filter_label = Enum.at(brainstorming.labels, 0)
      Brainstormings.update_brainstorming(brainstorming, %{filter_labels_ids: [filter_label.id]})
      {:ok, reloaded_brainstorming} = Brainstormings.get_brainstorming(brainstorming.id)
      assert reloaded_brainstorming.filter_labels_ids == [filter_label.id]
    end

    test "updates the brainstorming with empty filter_labels_ids", %{brainstorming: brainstorming} do
      filter_label = Enum.at(brainstorming.labels, 0)
      Brainstormings.update_brainstorming(brainstorming, %{filter_labels_ids: [filter_label.id]})
      Brainstormings.update_brainstorming(brainstorming, %{filter_labels_ids: []})
      {:ok, reloaded_brainstorming} = Brainstormings.get_brainstorming(brainstorming.id)
      assert reloaded_brainstorming.filter_labels_ids == []
    end
  end

  describe "get_brainstorming" do
    test "returns the brainstorming", %{brainstorming: brainstorming} do
      {:ok, loaded_brainstorming} = Brainstormings.get_brainstorming(brainstorming.id)
      assert loaded_brainstorming.id == brainstorming.id
    end

    test "returns an error for the wrong uuid" do
      assert {:error, :invalid_uuid} == Brainstormings.get_brainstorming("invalid_uuid")
    end

    test "returns an error for a missing brainstorming" do
      assert {:error, :not_found} ==
               Brainstormings.get_brainstorming("8a4f5d37-28c4-424e-ac4a-5637a41486c4")
    end

    test "returns an error for a nil value" do
      assert {:error, :invalid_uuid} ==
               Brainstormings.get_brainstorming(nil)
    end
  end

  describe "validate_admin_secret" do
    test "returns false if secret is wrong", %{brainstorming: brainstorming} do
      refute Brainstormings.validate_admin_secret(brainstorming, "wrong")
    end

    test "returns false if secret is nil", %{brainstorming: brainstorming} do
      brainstorming = %{brainstorming | admin_url_id: nil}
      refute Brainstormings.validate_admin_secret(brainstorming, nil)
    end

    test "returns true if secret is correct", %{brainstorming: brainstorming} do
      assert Brainstormings.validate_admin_secret(brainstorming, brainstorming.admin_url_id)
    end
  end

  describe "create_brainstorming" do
    test "creates a lane", %{user: user} do
      {:ok, brainstorming} = Brainstormings.create_brainstorming(user, %{name: "test"})
      assert length(brainstorming.lanes) == 1
    end

    test "creates labels", %{user: user} do
      {:ok, brainstorming} = Brainstormings.create_brainstorming(user, %{name: "test"})
      assert length(brainstorming.labels) == 5
    end
  end

  describe "list_brainstormings_for" do
    test "returns the 3 most recent brainstormings", %{brainstorming: brainstorming, user: user} do
      older_brainstorming =
        Factory.insert!(:brainstorming, inserted_at: ~N[2021-01-10 15:04:30], users: [user])

      oldest_brainstorming =
        Factory.insert!(:brainstorming, inserted_at: ~N[2021-01-05 15:04:30], users: [user])

      assert Brainstormings.list_brainstormings_for(user.id) |> Enum.map(fn b -> b.id end) == [
               brainstorming.id,
               older_brainstorming.id,
               oldest_brainstorming.id
             ]
    end
  end

  describe "change brainstorming" do
    test "shortens the brainstorming name if it is too long", %{brainstorming: brainstorming} do
      result =
        Brainstormings.change_brainstorming(brainstorming, %{
          name: """
          Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. \
          """
        })

      assert result.changes.name == """
             Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores e\
             """
    end
  end

  describe "delete_old_brainstormings" do
    test "removes the brainstorming" do
      old_brainstorming =
        Factory.insert!(:brainstorming,
          last_accessed_at: DateTime.from_naive!(~N[2021-01-01 10:00:00], "Etc/UTC")
        )

      Brainstormings.delete_old_brainstormings()

      refute Repo.exists?(from(b in Brainstorming, where: b.id == ^old_brainstorming.id))
    end

    test "removes a recently inactive brainstorming " do
      days = 30

      inactive_brainstorming =
        Factory.insert!(:brainstorming,
          last_accessed_at:
            DateTime.utc_now() |> Timex.shift(days: -days - 1) |> DateTime.truncate(:second)
        )

      Brainstormings.delete_old_brainstormings(days)

      refute Repo.exists?(from(b in Brainstorming, where: b.id == ^inactive_brainstorming.id))
    end

    test "does not remove a recently accessed brainstorming " do
      days = 30

      active_brainstorming =
        Factory.insert!(
          :brainstorming,
          last_accessed_at:
            DateTime.utc_now() |> Timex.shift(days: -days + 1) |> DateTime.truncate(:second)
        )

      Brainstormings.delete_old_brainstormings(days)

      assert Repo.exists?(from(b in Brainstorming, where: b.id == ^active_brainstorming.id))
    end

    test "removes the old brainstormings ideas" do
      old_brainstorming =
        Factory.insert!(:brainstorming,
          last_accessed_at: DateTime.from_naive!(~N[2021-01-01 10:00:00], "Etc/UTC")
        )

      old_idea =
        Factory.insert!(:idea,
          brainstorming: old_brainstorming,
          inserted_at: ~N[2021-01-01 15:04:30]
        )

      Brainstormings.delete_old_brainstormings()

      refute Repo.exists?(from(i in Idea, where: i.id == ^old_idea.id))
    end

    test "removes the old brainstormings likes" do
      old_brainstorming =
        Factory.insert!(:brainstorming,
          last_accessed_at: DateTime.from_naive!(~N[2021-01-01 10:00:00], "Etc/UTC")
        )

      old_idea =
        Factory.insert!(:idea,
          brainstorming: old_brainstorming,
          inserted_at: ~N[2021-01-01 15:04:30]
        )

      old_like = Factory.insert!(:like, idea: old_idea)
      Brainstormings.delete_old_brainstormings()

      refute Repo.exists?(from(l in Like, where: l.id == ^old_like.id))
    end

    test "removes the old brainstormings links" do
      old_brainstorming =
        Factory.insert!(:brainstorming,
          last_accessed_at: DateTime.from_naive!(~N[2021-01-01 10:00:00], "Etc/UTC")
        )

      old_idea =
        Factory.insert!(:idea,
          brainstorming: old_brainstorming,
          inserted_at: ~N[2021-01-01 15:04:30]
        )

      old_link = Factory.insert!(:link, idea: old_idea)
      Brainstormings.delete_old_brainstormings()

      refute Repo.exists?(from(l in Attachments.Link, where: l.id == ^old_link.id))
    end

    test "removes the old brainstormings ideas comments" do
      old_brainstorming =
        Factory.insert!(:brainstorming,
          last_accessed_at: DateTime.from_naive!(~N[2021-01-01 10:00:00], "Etc/UTC")
        )

      old_idea =
        Factory.insert!(:idea,
          brainstorming: old_brainstorming,
          inserted_at: ~N[2021-01-01 15:04:30]
        )

      old_comment = Factory.insert!(:comment, idea: old_idea)
      Brainstormings.delete_old_brainstormings()

      refute Repo.exists?(from(c in Comment, where: c.id == ^old_comment.id))
    end

    test "removes file attachments" do
      old_brainstorming =
        Factory.insert!(:brainstorming,
          last_accessed_at: DateTime.from_naive!(~N[2021-01-01 10:00:00], "Etc/UTC")
        )

      old_idea =
        Factory.insert!(:idea,
          brainstorming: old_brainstorming,
          inserted_at: ~N[2021-01-01 15:04:30]
        )

      file_path = Path.join("priv/static/uploads", "test")
      # create a test file which is used as an attachment
      File.write(file_path, "test")

      old_attachment = Factory.insert!(:file, idea: old_idea, path: "uploads/test")
      Brainstormings.delete_old_brainstormings()

      refute File.exists?(file_path)
      refute Repo.exists?(from(file in Attachments.File, where: file.id == ^old_attachment.id))
    end

    test "removes the old brainstormings users connection", %{user: user} do
      old_brainstorming =
        Factory.insert!(:brainstorming,
          users: [user],
          last_accessed_at: DateTime.from_naive!(~N[2021-01-01 10:00:00], "Etc/UTC")
        )

      Brainstormings.delete_old_brainstormings()

      refute Enum.member?(Brainstormings.list_brainstormings_for(user.id), old_brainstorming.id)
    end

    test "does not remove the user", %{user: user} do
      inactive_brainstorming =
        Factory.insert!(:brainstorming,
          users: [user],
          last_accessed_at: DateTime.from_naive!(~N[2021-01-01 10:00:00], "Etc/UTC")
        )

      Brainstormings.delete_old_brainstormings()

      refute Repo.exists?(from(b in Brainstorming, where: b.id == ^inactive_brainstorming.id))
      assert Repo.exists?(from(u in User, where: u.id == ^user.id))
    end

    test "keeps the new brainstorming", %{brainstorming: brainstorming} do
      Brainstormings.delete_old_brainstormings()

      assert Repo.exists?(from(b in Brainstorming, where: b.id == ^brainstorming.id))
    end
  end

  describe "empty/1 brainstormings" do
    test "empty/1 removes all ideas from a brainstorming", %{brainstorming: brainstorming} do
      brainstorming = brainstorming |> Repo.preload([:ideas])
      assert Enum.count(brainstorming.ideas) == 1
      Brainstormings.empty(brainstorming)
      # reload brainstorming:
      {:ok, brainstorming} = Brainstormings.get_brainstorming(brainstorming.id)
      brainstorming = brainstorming |> Repo.preload([:ideas, :lanes])
      assert Enum.empty?(brainstorming.lanes)
    end

    test "empty/1 also clears likes and labels from ideas", %{
      brainstorming: brainstorming,
      lane: lane
    } do
      idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          inserted_at: ~N[2021-01-01 15:04:30],
          lane: lane
        )

      like = Factory.insert!(:like, idea: idea)

      {:ok, _idea_idea_label} =
        IdeaLabels.add_idea_label_to_idea(idea, Enum.at(brainstorming.labels, 0).id)

      idea = idea |> Repo.preload([:idea_labels])

      Brainstormings.empty(brainstorming)
      # reload brainstorming:
      lanes = Lanes.get_lanes_for_brainstorming(brainstorming.id)

      assert Enum.empty?(lanes)
      assert Repo.get_by(Idea, id: idea.id) == nil
      assert Repo.get_by(IdeaIdeaLabel, idea_id: idea.id) == nil
      assert Repo.get_by(Like, id: like.id) == nil
    end

    test "empty/1 does not removes all ideas from other brainstormings", %{
      brainstorming: brainstorming
    } do
      other_brainstorming = Factory.insert!(:brainstorming)
      other_lane = Enum.at(brainstorming.lanes, 0)

      Factory.insert!(:idea,
        brainstorming: other_brainstorming,
        lane: other_lane
      )

      other_brainstorming = other_brainstorming |> Repo.preload([:ideas])

      assert Enum.count(other_brainstorming.ideas) == 1
      Brainstormings.empty(brainstorming)
      # reload brainstorming:
      {:ok, brainstorming} = Brainstormings.get_brainstorming(brainstorming.id)
      brainstorming = brainstorming |> Repo.preload([:ideas, :lanes])
      other_brainstorming = other_brainstorming |> Repo.preload([:ideas])
      assert Enum.empty?(brainstorming.lanes)
      assert Enum.count(other_brainstorming.lanes) == 1
    end
  end

  describe "preload_idea_for_broadcast/1" do
    test "preloads all required associations for an idea with no associations", %{
      brainstorming: brainstorming,
      lane: lane
    } do
      # Create an idea without preloading any associations
      idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane
        )

      # Verify associations are not loaded initially
      refute Ecto.assoc_loaded?(idea.link)
      refute Ecto.assoc_loaded?(idea.likes)
      refute Ecto.assoc_loaded?(idea.idea_labels)
      refute Ecto.assoc_loaded?(idea.files)
      refute Ecto.assoc_loaded?(idea.comments)

      # Preload associations
      preloaded_idea = Brainstormings.preload_idea_for_broadcast(idea)

      # Verify all associations are now loaded
      assert Ecto.assoc_loaded?(preloaded_idea.link)
      assert Ecto.assoc_loaded?(preloaded_idea.likes)
      assert Ecto.assoc_loaded?(preloaded_idea.idea_labels)
      assert Ecto.assoc_loaded?(preloaded_idea.files)
      assert Ecto.assoc_loaded?(preloaded_idea.comments)
    end

    test "preloads associations for an idea with a link attachment", %{
      brainstorming: brainstorming,
      lane: lane
    } do
      idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane
        )

      link = Factory.insert!(:link, idea: idea, url: "https://example.com")

      preloaded_idea = Brainstormings.preload_idea_for_broadcast(idea)

      assert Ecto.assoc_loaded?(preloaded_idea.link)
      assert preloaded_idea.link.id == link.id
      assert preloaded_idea.link.url == "https://example.com"
    end

    test "preloads associations for an idea with likes", %{
      brainstorming: brainstorming,
      lane: lane
    } do
      idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane
        )

      user1 = Factory.insert!(:user)
      user2 = Factory.insert!(:user)
      like1 = Factory.insert!(:like, idea: idea, user: user1)
      like2 = Factory.insert!(:like, idea: idea, user: user2)

      preloaded_idea = Brainstormings.preload_idea_for_broadcast(idea)

      assert Ecto.assoc_loaded?(preloaded_idea.likes)
      assert length(preloaded_idea.likes) == 2
      assert Enum.any?(preloaded_idea.likes, &(&1.id == like1.id))
      assert Enum.any?(preloaded_idea.likes, &(&1.id == like2.id))
    end

    test "preloads associations for an idea with idea_labels", %{
      brainstorming: brainstorming,
      lane: lane
    } do
      idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane
        )

      label = Enum.at(brainstorming.labels, 0)
      {:ok, _idea_idea_label} = IdeaLabels.add_idea_label_to_idea(idea, label.id)

      preloaded_idea = Brainstormings.preload_idea_for_broadcast(idea)

      assert Ecto.assoc_loaded?(preloaded_idea.idea_labels)
      assert length(preloaded_idea.idea_labels) == 1
      assert Enum.at(preloaded_idea.idea_labels, 0).id == label.id
    end

    test "preloads associations for an idea with file attachments", %{
      brainstorming: brainstorming,
      lane: lane
    } do
      idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane
        )

      file = Factory.insert!(:file, idea: idea, path: "uploads/test.png")

      preloaded_idea = Brainstormings.preload_idea_for_broadcast(idea)

      assert Ecto.assoc_loaded?(preloaded_idea.files)
      assert length(preloaded_idea.files) == 1
      assert Enum.at(preloaded_idea.files, 0).id == file.id
    end

    test "preloads associations for an idea with comments", %{
      brainstorming: brainstorming,
      lane: lane
    } do
      idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane
        )

      comment1 = Factory.insert!(:comment, idea: idea, body: "First comment")
      comment2 = Factory.insert!(:comment, idea: idea, body: "Second comment")

      preloaded_idea = Brainstormings.preload_idea_for_broadcast(idea)

      assert Ecto.assoc_loaded?(preloaded_idea.comments)
      assert length(preloaded_idea.comments) == 2
      assert Enum.any?(preloaded_idea.comments, &(&1.id == comment1.id))
      assert Enum.any?(preloaded_idea.comments, &(&1.id == comment2.id))
    end

    test "preloads all associations for an idea with all attachment types", %{
      brainstorming: brainstorming,
      lane: lane,
      user: user
    } do
      idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane
        )

      # Add all types of associations
      link = Factory.insert!(:link, idea: idea, url: "https://example.com")
      like = Factory.insert!(:like, idea: idea, user: user)
      label = Enum.at(brainstorming.labels, 0)
      {:ok, _idea_idea_label} = IdeaLabels.add_idea_label_to_idea(idea, label.id)
      file = Factory.insert!(:file, idea: idea, path: "uploads/test.png")
      comment = Factory.insert!(:comment, idea: idea, body: "A comment")

      preloaded_idea = Brainstormings.preload_idea_for_broadcast(idea)

      # Verify all associations are loaded
      assert Ecto.assoc_loaded?(preloaded_idea.link)
      assert Ecto.assoc_loaded?(preloaded_idea.likes)
      assert Ecto.assoc_loaded?(preloaded_idea.idea_labels)
      assert Ecto.assoc_loaded?(preloaded_idea.files)
      assert Ecto.assoc_loaded?(preloaded_idea.comments)

      # Verify the data is correct
      assert preloaded_idea.link.id == link.id
      assert length(preloaded_idea.likes) == 1
      assert Enum.at(preloaded_idea.likes, 0).id == like.id
      assert length(preloaded_idea.idea_labels) == 1
      assert Enum.at(preloaded_idea.idea_labels, 0).id == label.id
      assert length(preloaded_idea.files) == 1
      assert Enum.at(preloaded_idea.files, 0).id == file.id
      assert length(preloaded_idea.comments) == 1
      assert Enum.at(preloaded_idea.comments, 0).id == comment.id
    end

    test "works correctly when associations are already loaded", %{
      brainstorming: brainstorming,
      lane: lane
    } do
      idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane
        )

      # Preload once
      first_preload = Brainstormings.preload_idea_for_broadcast(idea)

      # Preload again - should not cause issues
      second_preload = Brainstormings.preload_idea_for_broadcast(first_preload)

      # All associations should still be loaded
      assert Ecto.assoc_loaded?(second_preload.link)
      assert Ecto.assoc_loaded?(second_preload.likes)
      assert Ecto.assoc_loaded?(second_preload.idea_labels)
      assert Ecto.assoc_loaded?(second_preload.files)
      assert Ecto.assoc_loaded?(second_preload.comments)
    end
  end

  describe "broadcast/2 with idea" do
    test "broadcasts idea with preloaded associations without additional queries", %{
      brainstorming: brainstorming,
      lane: lane,
      user: user
    } do
      idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane
        )

      # Add associations
      Factory.insert!(:link, idea: idea, url: "https://example.com")
      Factory.insert!(:like, idea: idea, user: user)
      Factory.insert!(:comment, idea: idea, body: "Test comment")

      # Preload associations before broadcasting
      idea_with_associations = Brainstormings.preload_idea_for_broadcast(idea)

      # Broadcast should succeed and return the original idea (not the one with associations)
      assert {:ok, returned_idea} =
               Brainstormings.broadcast({:ok, idea_with_associations}, :idea_updated)

      assert returned_idea.id == idea.id
    end

    test "broadcasts idea without preloaded associations (fallback behavior)", %{
      brainstorming: brainstorming,
      lane: lane
    } do
      idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane
        )

      # DO NOT preload associations - test the fallback behavior
      refute Ecto.assoc_loaded?(idea.link)
      refute Ecto.assoc_loaded?(idea.likes)

      # Broadcast should still succeed by preloading internally
      assert {:ok, returned_idea} = Brainstormings.broadcast({:ok, idea}, :idea_added)
      assert returned_idea.id == idea.id
    end

    test "broadcasts idea with partially loaded associations", %{
      brainstorming: brainstorming,
      lane: lane
    } do
      idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane
        )
        |> Repo.preload([:link, :likes])

      # Some associations are loaded, some are not
      assert Ecto.assoc_loaded?(idea.link)
      assert Ecto.assoc_loaded?(idea.likes)
      refute Ecto.assoc_loaded?(idea.idea_labels)
      refute Ecto.assoc_loaded?(idea.files)
      refute Ecto.assoc_loaded?(idea.comments)

      # Broadcast should trigger fallback preloading for missing associations
      assert {:ok, returned_idea} = Brainstormings.broadcast({:ok, idea}, :idea_updated)
      assert returned_idea.id == idea.id
    end

    test "returns the original idea unchanged in the tuple", %{
      brainstorming: brainstorming,
      lane: lane
    } do
      idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane
        )

      # Broadcast without preloading
      assert {:ok, returned_idea} = Brainstormings.broadcast({:ok, idea}, :idea_added)

      # The returned idea should be the same struct (not reloaded)
      assert returned_idea == idea
      # Verify associations are still not loaded on the returned idea
      refute Ecto.assoc_loaded?(returned_idea.link)
      refute Ecto.assoc_loaded?(returned_idea.likes)
    end

    test "broadcasts different event types correctly", %{
      brainstorming: brainstorming,
      lane: lane
    } do
      idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane
        )

      preloaded_idea = Brainstormings.preload_idea_for_broadcast(idea)

      # Test various event types
      assert {:ok, _} = Brainstormings.broadcast({:ok, preloaded_idea}, :idea_added)
      assert {:ok, _} = Brainstormings.broadcast({:ok, preloaded_idea}, :idea_updated)
      assert {:ok, _} = Brainstormings.broadcast({:ok, preloaded_idea}, :idea_deleted)
    end

    test "broadcasts to the correct topic based on brainstorming_id", %{
      brainstorming: brainstorming,
      lane: lane
    } do
      idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane
        )

      preloaded_idea = Brainstormings.preload_idea_for_broadcast(idea)

      # Subscribe to the correct topic
      Phoenix.PubSub.subscribe(Mindwendel.PubSub, "brainstormings:" <> brainstorming.id)

      # Broadcast
      Brainstormings.broadcast({:ok, preloaded_idea}, :idea_added)

      # Verify we received the message
      assert_receive {:idea_added, broadcasted_idea}
      assert broadcasted_idea.id == idea.id

      # Verify the broadcasted idea has all associations loaded
      assert Ecto.assoc_loaded?(broadcasted_idea.link)
      assert Ecto.assoc_loaded?(broadcasted_idea.likes)
      assert Ecto.assoc_loaded?(broadcasted_idea.idea_labels)
      assert Ecto.assoc_loaded?(broadcasted_idea.files)
      assert Ecto.assoc_loaded?(broadcasted_idea.comments)
    end

    test "broadcasts idea with nil link (has_one association with no record)", %{
      brainstorming: brainstorming,
      lane: lane
    } do
      idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane
        )

      # DO NOT add a link - test that nil link is handled correctly
      preloaded_idea = Brainstormings.preload_idea_for_broadcast(idea)

      # Verify link is loaded but nil (no link exists)
      assert Ecto.assoc_loaded?(preloaded_idea.link)
      assert preloaded_idea.link == nil

      # Broadcast should work fine
      assert {:ok, _} = Brainstormings.broadcast({:ok, preloaded_idea}, :idea_added)
    end

    test "broadcasts idea with empty collections (has_many associations with no records)", %{
      brainstorming: brainstorming,
      lane: lane
    } do
      idea =
        Factory.insert!(:idea,
          brainstorming: brainstorming,
          lane: lane
        )

      # DO NOT add any likes, labels, files, or comments
      preloaded_idea = Brainstormings.preload_idea_for_broadcast(idea)

      # Verify collections are loaded but empty
      assert Ecto.assoc_loaded?(preloaded_idea.likes)
      assert preloaded_idea.likes == []
      assert Ecto.assoc_loaded?(preloaded_idea.idea_labels)
      assert preloaded_idea.idea_labels == []
      assert Ecto.assoc_loaded?(preloaded_idea.files)
      assert preloaded_idea.files == []
      assert Ecto.assoc_loaded?(preloaded_idea.comments)
      assert preloaded_idea.comments == []

      # Broadcast should work fine
      assert {:ok, _} = Brainstormings.broadcast({:ok, preloaded_idea}, :idea_added)
    end
  end
end
