defmodule Mindwendel.AttachmentsTest do
  use Mindwendel.DataCase
  alias Mindwendel.Factory
  alias Mindwendel.Attachments

  setup do
    upload_path = "priv/static/uploads/"
    File.mkdir_p!(Path.dirname(upload_path))
  end

  describe "get_attached_file" do
    test "returns the file" do
      attachment = Factory.insert!(:file)
      assert Attachments.get_attached_file(attachment.id) == attachment
    end
  end

  describe "delete_attached_file" do
    test "deletes the file" do
      idea =
        Factory.insert!(:idea,
          inserted_at: ~N[2021-01-01 15:04:30]
        )

      file_path = "priv/static/uploads/attachment_test"
      # create a test file which is used as an attachment
      File.write(file_path, "test")

      attachment = Factory.insert!(:file, idea: idea, path: "uploads/attachment_test")
      Attachments.delete_attached_file(attachment)

      refute File.exists?(file_path)
      refute Repo.exists?(from(f in Attachments.File, where: f.id == ^attachment.id))
    end
  end

  describe "change_attached_file" do
    test "changes an attached file" do
      attachment = Factory.insert!(:file)

      result = Attachments.change_attached_file(attachment, %{name: "test"})
      assert result.changes.name == "test"
    end
  end
end
