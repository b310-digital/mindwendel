defmodule Mindwendel.AI.Config.DefaultImpl do
  @behaviour Mindwendel.AI.Config

  @impl Mindwendel.AI.Config
  def fetch_ai_config! do
    Application.fetch_env!(:mindwendel, :ai)
  end
end
