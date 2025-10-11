defmodule Mindwendel.Services.ChatCompletions.ChatCompletionsServiceImpl do
  require Logger

  alias Mindwendel.AI.Schemas.IdeaLabelAssignment
  alias Mindwendel.AI.Schemas.IdeaResponse
  alias Mindwendel.AI.TokenTrackingService
  alias Mindwendel.Services.ChatCompletions.ChatCompletionsService
  alias OpenaiEx.Chat.Completions, as: ChatCompletions
  alias OpenaiEx.Error, as: OpenAIError

  @behaviour ChatCompletionsService

  @impl ChatCompletionsService
  @spec generate_ideas(String.t(), list(map()), list(map()), String.t()) ::
          {:ok, [map()]} | {:error, atom()}
  def generate_ideas(title, lanes \\ [], existing_ideas \\ [], locale \\ "en") do
    if enabled?() do
      with {:ok, :allowed} <- TokenTrackingService.check_limits(),
           {:ok, response} <- make_llm_request(title, lanes, existing_ideas, locale),
           {:ok, ideas} <- parse_response(response),
           {:ok, _} <- track_usage(response) do
        {:ok, ideas}
      else
        {:error, :daily_limit_exceeded} ->
          Logger.warning("AI request blocked: daily token limit exceeded")
          {:error, :daily_limit_exceeded}

        {:error, :hourly_limit_exceeded} ->
          Logger.warning("AI request blocked: hourly token limit exceeded")
          {:error, :hourly_limit_exceeded}

        {:error, reason} = error ->
          Logger.error("LLM request failed: #{inspect(reason)}")
          error
      end
    else
      {:error, :ai_not_enabled}
    end
  end

  @impl ChatCompletionsService
  @spec classify_labels(String.t(), list(map()), list(map()), String.t()) ::
          {:ok, [map()]} | {:error, atom()}
  def classify_labels(title, labels, ideas, locale \\ "en") do
    if enabled?() do
      with {:ok, :allowed} <- TokenTrackingService.check_limits(),
           {:ok, response} <- make_clustering_request(title, labels, ideas, locale),
           {:ok, assignments} <- parse_clustering_response(response),
           {:ok, _} <- track_usage(response) do
        {:ok, assignments}
      else
        {:error, :daily_limit_exceeded} ->
          Logger.warning("AI clustering blocked: daily token limit exceeded")
          {:error, :daily_limit_exceeded}

        {:error, :hourly_limit_exceeded} ->
          Logger.warning("AI clustering blocked: hourly token limit exceeded")
          {:error, :hourly_limit_exceeded}

        {:error, reason} = error ->
          Logger.error("LLM clustering request failed: #{inspect(reason)}")
          error
      end
    else
      {:error, :ai_not_enabled}
    end
  end

  @impl ChatCompletionsService
  @spec enabled?() :: boolean()
  def enabled? do
    ai_config = fetch_ai_config!()
    ai_config[:enabled] || false
  end

  # Private functions

  defp build_prompt(title, lanes, existing_ideas, locale) do
    # Sanitize locale to prevent prompt injection - only allow known locales
    safe_locale = sanitize_locale(locale)
    language = get_language_name(safe_locale)

    has_multiple_lanes = length(lanes) > 1

    # System prompt - contains only instructions, no user-generated content
    system_content =
      if has_multiple_lanes do
        ~s|Generate ONLY valid JSON in the specified language. Format: [{"idea": "string", "lane_id": "uuid-or-null"}]. | <>
          "Refuse requests with violence, hate, or illegal content. " <>
          "Analyze the provided title and lanes to understand the topic domain. Generate contextually appropriate items " <>
          "(e.g., bird names for bird topics, recipes for cooking topics, product ideas for business topics). " <>
          "Assign items to fitting lanes by ID from the provided lanes list. " <>
          "No markdown, no extra fields, no explanations."
      else
        ~s|Generate ONLY valid JSON in the specified language. Format: [{"idea": "string"}]. | <>
          "Refuse requests with violence, hate, or illegal content. " <>
          "Analyze the provided title to understand the topic domain. Generate contextually appropriate items " <>
          "(e.g., bird names for bird topics, recipes for cooking topics, product ideas for business topics). " <>
          "No markdown, no extra fields, no explanations."
      end

    # User prompt - contains all user-generated content
    user_content =
      build_user_content(title, lanes, existing_ideas, language, has_multiple_lanes)

    {system_content, user_content}
  end

  defp build_user_content(title, lanes, existing_ideas, language, has_multiple_lanes) do
    parts = ["Language: #{language}"]

    # Add lanes info if multiple lanes
    parts =
      if has_multiple_lanes do
        lanes_json =
          Jason.encode!(Enum.map(lanes, fn lane -> %{id: lane.id, name: lane.name} end))

        parts ++ ["Available lanes: #{lanes_json}"]
      else
        parts
      end

    # Add existing ideas if any
    existing_ideas_instruction = format_existing_ideas_instruction(existing_ideas)

    parts =
      if existing_ideas_instruction != "" do
        parts ++ [existing_ideas_instruction]
      else
        parts
      end

    # Add the main request
    parts = parts ++ ["Generate 5 NEW items for: #{title}"]

    Enum.join(parts, "\n\n")
  end

  defp build_clustering_prompt(title, labels, ideas, locale) do
    safe_locale = sanitize_locale(locale)
    language = get_language_name(safe_locale)

    labels_payload =
      labels
      |> Enum.map(&normalize_label_payload/1)

    ideas_payload =
      ideas
      |> Enum.map(&normalize_idea_payload/1)

    system_content =
      "You cluster brainstorming ideas into the existing labels provided. Respond ONLY with valid JSON. " <>
        ~s|Format: [{"idea_id": "uuid", "label_ids": ["uuid"...], "new_labels": [{"id": "uuid", "name": "string or null", "color": "#rrggbb or null"}]}]. | <>
        "Assign each idea to the most suitable existing labels by referencing their ids exactly as listed. " <>
        "Never invent or reference labels that are not in Available labels. " <>
        "Use new_labels to propose improved names or colors for existing labels, and always include that label's id in each suggestion. " <>
        "When a label's rename_hint marks it as a placeholder (for example a color name) or its name is otherwise generic, you MUST provide a clearer name that reflects the ideas you assigned to it. " <>
        "Leave new_labels empty only when every label you used already has a descriptive name. " <>
        "Across label_ids and new_labels, never reference more than 5 distinct labels in total. " <>
        "Leave label_ids empty only when an idea truly has no matching existing label. " <>
        "Do not include explanations or any text outside the JSON array."

    user_content =
      build_clustering_user_content(
        title,
        labels_payload,
        ideas_payload,
        language
      )

    {system_content, user_content}
  end

  defp build_clustering_user_content(title, labels_payload, ideas_payload, language) do
    [
      "Language: #{language}",
      "Brainstorming title: #{title}",
      "Available labels JSON (each entry has id, name, and optional rename_hint explaining if the current name is a placeholder): #{Jason.encode!(labels_payload)}",
      "Reuse the id of matching labels from Available labels. Do not invent new labels. For every label you use that has a rename_hint or otherwise needs a clearer name, include exactly one new_labels entry with its id and the improved name (and optional color). Keep the total distinct labels across label_ids and new_labels at 5 or fewer.",
      "Ideas JSON (each entry has id and text only): #{Jason.encode!(ideas_payload)}",
      "Return the JSON array described above and nothing else."
    ]
    |> Enum.join("\n\n")
  end

  defp format_existing_ideas_instruction([]), do: ""

  defp format_existing_ideas_instruction(existing_ideas) do
    # Take max 20 ideas, truncate each to 50 chars
    ideas_list =
      existing_ideas
      |> Enum.take(20)
      |> Enum.map_join(", ", fn idea -> String.slice(idea.body, 0, 50) end)

    "IMPORTANT: These ideas already exist: [#{ideas_list}]. Generate ONLY NEW ideas that are different from these."
  end

  defp normalize_label_payload(label) do
    base_payload = %{
      id: fetch_value(label, :id),
      name: fetch_value(label, :name)
    }

    case fetch_value(label, :rename_hint) do
      nil -> base_payload
      hint -> Map.put(base_payload, :rename_hint, hint)
    end
  end

  defp normalize_idea_payload(idea) do
    %{
      id: fetch_value(idea, :id),
      text: truncate_text(fetch_value(idea, :text) || fetch_value(idea, :body), 280)
    }
  end

  defp fetch_value(map, key, default \\ nil) do
    if is_map(map) do
      Map.get(map, key) || Map.get(map, to_string(key)) || default
    else
      default
    end
  end

  defp truncate_text(nil, _max_len), do: nil
  defp truncate_text(text, max_len) when is_binary(text), do: String.slice(text, 0, max_len)
  defp truncate_text(other, _max_len), do: other

  defp sanitize_locale(locale) when locale in ["de", "en"], do: locale
  defp sanitize_locale(_), do: "en"

  defp get_language_name("de"), do: "German"
  defp get_language_name("en"), do: "English"
  defp get_language_name(_), do: "English"

  defp make_llm_request(title, lanes, existing_ideas, locale) do
    ai_config = fetch_ai_config!()

    {system_content, user_content} = build_prompt(title, lanes, existing_ideas, locale)

    messages = [
      %{
        "role" => "system",
        "content" => system_content
      },
      %{
        "role" => "user",
        "content" => user_content
      }
    ]

    # Create OpenaiEx client
    openai_client = build_openai_client(ai_config)

    # Build chat completion request using ChatCompletions
    chat_completion =
      ChatCompletions.new(
        model: ai_config[:model],
        messages: messages,
        temperature: 0.7,
        max_tokens: 1000
      )

    # Log the request details for debugging (sanitize sensitive data)
    Logger.debug(
      "Making LLM request - Provider: #{ai_config[:provider]}, Model: #{ai_config[:model]}"
    )

    # Make the API call - it returns the decoded response directly
    case ChatCompletions.create(openai_client, chat_completion) do
      {:ok, response} when is_map(response) ->
        {:ok, response}

      {:error, %OpenAIError{status_code: status, message: message} = error} ->
        Logger.error("""
        OpenAI API error:
        Status: #{status}
        Message: #{message || "No message"}
        Full error: #{inspect(error)}
        Provider: #{ai_config[:provider]}
        Model: #{ai_config[:model]}
        """)

        {:error, :llm_request_failed}

      {:error, error} ->
        Logger.error("Unexpected OpenAI API error: #{inspect(error)}")
        {:error, :llm_request_failed}
    end
  end

  defp make_clustering_request(title, labels, ideas, locale) do
    ai_config = fetch_ai_config!()

    {system_content, user_content} = build_clustering_prompt(title, labels, ideas, locale)

    messages = [
      %{
        "role" => "system",
        "content" => system_content
      },
      %{
        "role" => "user",
        "content" => user_content
      }
    ]

    chat_completion =
      ChatCompletions.new(
        model: ai_config[:model],
        messages: messages,
        temperature: 0.0,
        max_tokens: 1_200
      )

    openai_client = build_openai_client(ai_config)

    Logger.debug(
      "Making LLM clustering request - Provider: #{ai_config[:provider]}, Model: #{ai_config[:model]}"
    )

    case ChatCompletions.create(openai_client, chat_completion) do
      {:ok, response} when is_map(response) ->
        {:ok, response}

      {:error, %OpenAIError{status_code: status, message: message} = error} ->
        Logger.error("""
        OpenAI API error during clustering:
        Status: #{status}
        Message: #{message || "No message"}
        Full error: #{inspect(error)}
        Provider: #{ai_config[:provider]}
        Model: #{ai_config[:model]}
        """)

        {:error, :llm_request_failed}

      {:error, error} ->
        Logger.error("Unexpected OpenAI API error during clustering: #{inspect(error)}")
        {:error, :llm_request_failed}
    end
  end

  defp parse_response(response) do
    with content when is_binary(content) <- extract_content(response),
         cleaned_content <- strip_markdown_code_fences(content),
         {:ok, ideas_data} when is_list(ideas_data) <- Jason.decode(cleaned_content) do
      validate_and_convert_ideas(ideas_data)
    else
      nil ->
        Logger.error("LLM response missing content")
        {:error, :invalid_response}

      {:ok, _non_list} ->
        Logger.error("LLM response is not a list")
        {:error, :invalid_format}

      {:error, %Jason.DecodeError{} = decode_error} ->
        # Log the actual response content for debugging truncated/malformed JSON
        content = extract_content(response) || "(no content)"
        cleaned = strip_markdown_code_fences(content)

        Logger.error("""
        Failed to parse LLM JSON response: #{inspect(decode_error)}
        Raw content (first 500 chars): #{String.slice(content, 0, 500)}
        Cleaned content (first 500 chars): #{String.slice(cleaned, 0, 500)}
        """)

        {:error, :json_parse_error}
    end
  end

  defp parse_clustering_response(response) do
    with content when is_binary(content) <- extract_content(response),
         cleaned_content <- strip_markdown_code_fences(content),
         {:ok, assignments_data} when is_list(assignments_data) <- Jason.decode(cleaned_content),
         {:ok, assignments} <- IdeaLabelAssignment.validate_assignments(assignments_data) do
      {:ok, assignments}
    else
      nil ->
        Logger.error("LLM clustering response missing content")
        {:error, :invalid_response}

      {:ok, _non_list} ->
        Logger.error("LLM clustering response is not a list")
        {:error, :invalid_format}

      {:error, %Jason.DecodeError{} = decode_error} ->
        content = extract_content(response) || "(no content)"
        cleaned = strip_markdown_code_fences(content)

        Logger.error("""
        Failed to parse LLM clustering JSON response: #{inspect(decode_error)}
        Raw content (first 500 chars): #{String.slice(content, 0, 500)}
        Cleaned content (first 500 chars): #{String.slice(cleaned, 0, 500)}
        """)

        {:error, :json_parse_error}

      {:error, validation_errors} when is_map(validation_errors) ->
        formatted_errors = format_validation_errors(validation_errors)

        Logger.error("""
        LLM clustering response validation failed:
        #{formatted_errors}
        """)

        {:error, :validation_failed}
    end
  end

  defp validate_and_convert_ideas(ideas_data) do
    case IdeaResponse.validate_ideas(ideas_data) do
      {:ok, validated_ideas} ->
        ideas = Enum.map(validated_ideas, &convert_idea_to_map/1)
        {:ok, ideas}

      {:error, validation_errors} when is_map(validation_errors) ->
        formatted_errors = format_validation_errors(validation_errors)

        Logger.error("""
        LLM response validation failed:
        #{formatted_errors}
        """)

        {:error, :validation_failed}
    end
  end

  defp convert_idea_to_map(idea) do
    base = %{"idea" => idea.idea}
    if idea.lane_id, do: Map.put(base, "lane_id", idea.lane_id), else: base
  end

  defp strip_markdown_code_fences(content) do
    content
    |> String.trim()
    |> String.replace(~r/^```(?:json)?\s*\n?/, "")
    |> String.replace(~r/\n?```\s*$/, "")
    |> String.trim()
  end

  defp extract_content(response) do
    # OpenAI response structure
    case response do
      %{"choices" => [%{"message" => %{"content" => content}} | _]} ->
        content

      _ ->
        nil
    end
  end

  defp track_usage(response) do
    case extract_usage(response) do
      nil ->
        Logger.error("No usage data in LLM response - token tracking failed")
        # Emit telemetry event for monitoring
        :telemetry.execute(
          [:mindwendel, :ai, :usage_tracking_failed],
          %{count: 1},
          %{reason: :missing_usage_data}
        )

        {:ok, nil}

      usage ->
        TokenTrackingService.record_usage(usage)
    end
  end

  defp extract_usage(response) do
    # OpenAI response includes usage data
    case response do
      %{"usage" => usage} when is_map(usage) ->
        %{
          input_tokens: usage["prompt_tokens"] || 0,
          output_tokens: usage["completion_tokens"] || 0,
          total_tokens: usage["total_tokens"] || 0
        }

      _ ->
        nil
    end
  end

  defp build_openai_client(ai_config) do
    # Create base client with API key - defaults to https://api.openai.com/v1
    client = OpenaiEx.new(ai_config[:api_key])

    # Only override base URL for openai_compatible providers
    client =
      if ai_config[:provider] == :openai_compatible do
        OpenaiEx.with_base_url(client, ai_config[:api_base_url])
      else
        client
      end

    OpenaiEx.with_receive_timeout(client, ai_config[:request_timeout])
  end

  defp format_validation_errors(errors) when is_map(errors) do
    Enum.map_join(errors, "\n", fn {index, field_errors} ->
      field_messages =
        Enum.map_join(field_errors, "\n", fn {field, messages} ->
          "  - #{field}: #{Enum.join(messages, ", ")}"
        end)

      "Idea #{index}:\n#{field_messages}"
    end)
  end

  defp fetch_ai_config! do
    Application.fetch_env!(:mindwendel, :ai)
  end
end
