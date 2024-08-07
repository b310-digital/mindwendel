defmodule Mindwendel.Services.ChatCompletions.ChatCompletionsService do
  @callback generate_ideas(String.t()) :: {:error, any()} | {:ok, any()}
  @callback enabled?() :: boolean()

  # See https://hexdocs.pm/elixir_mock/getting_started.html for why we are doing it this way:
  def generate_ideas(title), do: impl().generate_ideas(title)
  def enabled?(), do: impl().enabled?

  defp impl,
    do:
      Application.get_env(
        :mindwendel,
        :chat_completions_service,
        Mindwendel.Services.ChatCompletions.ChatCompletionsServiceImpl
      )
end
