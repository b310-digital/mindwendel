defmodule Mindwendel.AI.Config do
  @callback fetch_ai_config!() :: keyword()

  def fetch_ai_config! do
    impl().fetch_ai_config!()
  end

  defp impl do
    Application.get_env(
      :mindwendel,
      :ai_config_service,
      Mindwendel.AI.Config.DefaultImpl
    )
  end
end
