defmodule Mindwendel.Help do
  @moduledoc """
  The Brainstormings context.
  """

  import Ecto.Query, warn: false
  alias Mindwendel.Repo
  alias Mindwendel.Help.Inspiration

  def random_inspiration do
    if Application.fetch_env!(:mindwendel, :options)[:feature_brainstorming_teasers] do
      Repo.one(from t in Inspiration, order_by: fragment("RANDOM()"), limit: 1)
    end
  end
end
