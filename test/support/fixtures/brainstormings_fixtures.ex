defmodule Mindwendel.BrainstormingsFixtures do
  alias Mindwendel.Factory

  @doc """
  Generate a brainstorming.
  """
  def brainstorming_fixture(user \\ Factory.insert!(:user), attrs \\ %{}) do
    new_attrs =
      attrs
      |> Enum.into(%{
        name: "How to brainstorm ideas?",
        # This can be removed as soon the todo is solved in lib/mindwendel/brainstormings/brainstorming.ex:12
        admin_url_id: Ecto.UUID.generate()
      })

    {:ok, brainstorming} = Mindwendel.Brainstormings.create_brainstorming(user, new_attrs)

    brainstorming
  end
end
