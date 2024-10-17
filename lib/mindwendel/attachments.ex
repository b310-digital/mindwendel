defmodule Mindwendel.Attachments do
  import Ecto.Query, warn: false
  alias Mindwendel.Repo
  alias Mindwendel.Brainstormings.Attachment

  require Logger

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking attachment changes.

  ## Examples

      iex> change_attachment(attachment)
      %Ecto.Changeset(data: %Attachment{})

  """
  def change_attachment(%Attachment{} = attachment, attrs \\ %{}) do
    Attachment.changeset(attachment, attrs)
  end
end
