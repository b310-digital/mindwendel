defmodule Mindwendel.Services.ChatCompletions.ChatCompletionsService do
  @callback generate_ideas(String.t(), list(map()), list(map()), String.t()) ::
              {:error, any()} | {:ok, any()}
  @callback enabled?() :: boolean()

  # See https://hexdocs.pm/elixir_mock/getting_started.html for why we are doing it this way:
  def generate_ideas(title, lanes \\ [], existing_ideas \\ [], locale \\ "en"),
    do: impl().generate_ideas(title, lanes, existing_ideas, locale)

  def enabled?(), do: impl().enabled?()

  defp impl,
    do:
      Application.get_env(
        :mindwendel,
        :chat_completions_service,
        Mindwendel.Services.ChatCompletions.ChatCompletionsServiceImpl
      )
end
