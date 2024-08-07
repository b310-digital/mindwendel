defmodule Mindwendel.Services.ChatCompletions.ChatCompletionsServiceImpl do
  require Logger

  alias Mindwendel.Services.ChatCompletions.ChatCompletionsService
  alias OpenaiEx.Chat
  alias OpenaiEx.ChatMessage

  @behaviour ChatCompletionsService

  @impl ChatCompletionsService
  def generate_ideas(title) do
    case setup_chat_completions_service() do
      {:ok, chat_completions_service} ->
        chat_req =
          Chat.Completions.new(
            model: "meta-llama-3-8b-instruct",
            messages: [
              ChatMessage.user(
                "Generate ONLY json for the following request, no other content. The format should be [{idea: generated_content}]. Replace generated_content."
              ),
              ChatMessage.user("In a  brainstorming, generate 5 ideas for the following title:"),
              ChatMessage.user(title)
            ]
          )

        ideas =
          case chat_completions_service |> Chat.Completions.create(chat_req) do
            {:ok, chat_response} ->
              choices = List.first(chat_response["choices"])
              Jason.decode!(choices["message"]["content"])

            {:error, error} ->
              Logger.error("Error while fetching ideas from LLM:")
              Logger.error(error)
              []
          end

        ideas

      _ ->
        {:error, "Error creating chat completion service"}
    end
  end

  @impl ChatCompletionsService
  @spec enabled?() :: boolean()
  def enabled? do
    ai_config = fetch_ai_config!()
    enabled?(ai_config)
  end

  def enabled?(ai_config) do
    ai_config[:enabled]
  end

  defp setup_chat_completions_service do
    ai_config = fetch_ai_config!()

    if enabled?(ai_config) do
      {:ok, OpenaiEx.new(api_key(ai_config)) |> OpenaiEx.with_base_url(api_base_url(ai_config))}
    else
      {:error, :ai_not_enabled}
    end
  end

  defp api_key(ai_config) do
    ai_config[:api_key]
  end

  defp api_base_url(ai_config) do
    ai_config[:api_base_url]
  end

  defp fetch_ai_config! do
    Application.fetch_env!(:mindwendel, :ai)
  end
end
