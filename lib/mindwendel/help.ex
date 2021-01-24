defmodule Mindwendel.Help do
  @moduledoc """
  The Brainstormings context.
  """

  import Ecto.Query, warn: false
  alias Mindwendel.Repo
  alias Mindwendel.Help.BrainstormingTechnique

  def random_brainstorming_technique do
    Repo.one(from t in BrainstormingTechnique, order_by: fragment("RANDOM()"), limit: 1)
  end
end
