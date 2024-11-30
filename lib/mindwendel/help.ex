defmodule Mindwendel.Help do
  @moduledoc """
  The Brainstormings context.
  """

  import Ecto.Query, warn: false
  alias Mindwendel.Repo
  alias Mindwendel.Help.Inspiration

  def random_inspiration do
    Repo.one(from t in Inspiration, order_by: fragment("RANDOM()"), limit: 1)
  end
end
