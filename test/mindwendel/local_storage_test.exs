defmodule Mindwendel.LocalStorageTest do
  use Mindwendel.DataCase, async: true
  alias Mindwendel.Factory
  alias Mindwendel.Accounts

  describe "brainstormings_from_local_storage_and_session" do
    test "returns empty list when input is nil" do
      assert [] ==
               Mindwendel.LocalStorage.brainstormings_from_local_storage_and_session(
                 nil,
                 nil,
                 nil
               )
    end

    test "returns local storage brainstormings" do
      local_storage_brainstormings = [
        %{
          "id" => Ecto.UUID.generate(),
          "last_accessed_at" => "2024-01-02T00:00:00Z",
          "name" => "Brainstorming 2"
        },
        %{
          "id" => Ecto.UUID.generate(),
          "last_accessed_at" => "2024-01-01T00:00:00Z",
          "name" => "Brainstorming 1"
        }
      ]

      merged_brainstormings =
        Mindwendel.LocalStorage.brainstormings_from_local_storage_and_session(
          local_storage_brainstormings,
          nil,
          nil
        )

      assert Enum.map(local_storage_brainstormings, & &1["id"]) ==
               Enum.map(merged_brainstormings, & &1["id"])
    end

    test "returns session brainstormings without a user" do
      session_brainstormings = [
        Factory.insert!(:brainstorming, %{
          last_accessed_at: ~U[2024-12-18 13:10:35Z],
          name: "Brainstorming 2"
        }),
        Factory.insert!(:brainstorming, %{
          last_accessed_at: ~U[2024-12-18 13:10:34Z],
          name: "Brainstorming 1"
        })
      ]

      merged_brainstormings =
        Mindwendel.LocalStorage.brainstormings_from_local_storage_and_session(
          nil,
          session_brainstormings,
          nil
        )

      assert Enum.map(session_brainstormings, & &1.id) ==
               Enum.map(merged_brainstormings, & &1["id"])
    end

    test "returns session brainstormings without admin_url_id if permission is missing" do
      session_brainstormings = [
        Factory.insert!(:brainstorming, %{
          last_accessed_at: ~U[2024-12-18 13:10:35Z],
          name: "Brainstorming 2"
        })
      ]

      merged_brainstormings =
        Mindwendel.LocalStorage.brainstormings_from_local_storage_and_session(
          nil,
          session_brainstormings,
          nil
        )

      assert List.first(merged_brainstormings)["admin_url_id"] == nil
    end

    test "returns session brainstormings with admin_url_id" do
      moderating_user = Factory.insert!(:user)
      brainstorming = Factory.insert!(:brainstorming)
      Accounts.add_moderating_user(brainstorming, moderating_user)

      session_brainstormings = [
        brainstorming
      ]

      merged_brainstormings =
        Mindwendel.LocalStorage.brainstormings_from_local_storage_and_session(
          nil,
          session_brainstormings,
          Accounts.get_user(moderating_user.id)
        )

      refute List.first(merged_brainstormings)["admin_url_id"] == nil
    end

    test "returns all brainstormings sorted by last_accessed_at" do
      session_brainstormings = [
        Factory.insert!(:brainstorming, %{
          last_accessed_at: ~U[2024-12-18 13:10:35Z],
          name: "Brainstorming 2"
        })
      ]

      local_storage_brainstormings = [
        %{
          "id" => Ecto.UUID.generate(),
          "last_accessed_at" => "2024-01-02T00:00:00Z",
          "name" => "Brainstorming 2"
        },
        %{
          "id" => Ecto.UUID.generate(),
          "last_accessed_at" => "2024-01-01T00:00:00Z",
          "name" => "Brainstorming 1"
        }
      ]

      merged_brainstormings =
        Mindwendel.LocalStorage.brainstormings_from_local_storage_and_session(
          local_storage_brainstormings,
          session_brainstormings,
          nil
        )

      assert Enum.map(session_brainstormings, & &1.id) ++
               Enum.map(local_storage_brainstormings, & &1["id"]) ==
               Enum.map(merged_brainstormings, & &1["id"])
    end

    test "returns no duplicated brainstormings" do
      session_brainstormings = [
        Factory.insert!(:brainstorming, %{
          last_accessed_at: ~U[2024-12-18 13:10:35Z],
          name: "Brainstorming 2"
        })
      ]

      local_storage_brainstormings = [
        %{
          "id" => List.first(session_brainstormings).id,
          "last_accessed_at" => "2024-01-02T00:00:00Z",
          "name" => "Brainstorming 2"
        }
      ]

      merged_brainstormings =
        Mindwendel.LocalStorage.brainstormings_from_local_storage_and_session(
          local_storage_brainstormings,
          session_brainstormings,
          nil
        )

      assert length(merged_brainstormings) == 1
    end
  end
end
