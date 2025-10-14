defmodule Mindwendel.Services.ChatCompletions.ChatCompletionsServiceImpl do
  require Logger

  alias Mindwendel.AI.Schemas.{IdeaLabelAssignment, LabelRename}
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

    # System prompt must contain only instructions, never user-generated content
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

    # System prompt must remain free of user-generated content to avoid prompt injection
    system_content =
      "You are a creative brainstorming facilitator clustering idea cards into the existing labels provided. Respond ONLY with valid JSON. " <>
        ~s|Format: {"assignments": [{"idea_id": "uuid", "label_ids": ["uuid"...]}], "renamed_labels": [{"id": "uuid", "name": "string"}]}. | <>
        "Study the idea texts and available label names to understand the brainstorming theme before assigning ideas. " <>
        "Assign each idea to the most suitable existing labels by referencing their ids exactly as listed. " <>
        "Never invent or reference labels that are not in Available labels. " <>
        "Use renamed_labels to propose refreshed names for labels you actually rely on so they feel specific to this brainstorm. " <>
        "Every rename must include the label's id and a short replacement name (maximum 15 characters, at most two words) that is vivid and avoids generic terms like \"Misc\" or \"General\". " <>
        "Do not repeat the original name or duplicate a renamed value across different labels. " <>
        "Emit an empty array for renamed_labels only when every existing label name is already precise. " <>
        "Across all label_ids, reference no more than 5 distinct label ids total. " <>
        "Leave label_ids empty only when an idea truly has no matching label. " <>
        "Do not include explanations or any text outside the JSON object."

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
      "Available labels JSON (each entry has id and name): #{Jason.encode!(labels_payload)}",
      "Reuse the ids of matching labels from Available labels. Do not invent additional labels. When you want to rename a label that you used, add a single entry inside renamed_labels with that label id and a replacement name (<=15 characters, max two words) that is vivid and distinct from the current name. Keep the total number of distinct labels referenced across all assignments at 5 or fewer, and only skip rename suggestions when the existing label name is already precise.",
      "Ideas JSON (each entry has id and text only): #{Jason.encode!(ideas_payload)}",
      "Return the JSON object described above and nothing else."
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
    %{
      id: fetch_value(label, :id),
      name: fetch_value(label, :name)
    }
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
         {:ok, payload} when is_map(payload) <- Jason.decode(cleaned_content),
         {:ok, %{assignments: assignments_data, renamed_labels: renamed_data}} <-
           normalize_clustering_payload(payload),
         {:ok, assignments} <- IdeaLabelAssignment.cast_assignments(assignments_data),
         {:ok, renamed_labels} <- LabelRename.cast_label_renames(renamed_data) do
      {:ok, %{assignments: assignments, renamed_labels: renamed_labels}}
    else
      nil ->
        Logger.error("LLM clustering response missing content")
        {:error, :invalid_response}

      {:ok, _non_map} ->
        Logger.error("LLM clustering response is not a JSON object")
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

      {:error, :invalid_format} ->
        Logger.error("LLM clustering response payload is missing assignments or uses an invalid structure")
        {:error, :invalid_format}

      {:error, validation_errors} when is_map(validation_errors) ->
        formatted_errors = format_validation_errors(validation_errors)

        Logger.error("""
        LLM clustering response validation failed:
        #{formatted_errors}
        """)

        {:error, :validation_failed}
    end
  end

  defp normalize_clustering_payload(payload) when is_map(payload) do
    assignments = Map.get(payload, "assignments") || Map.get(payload, :assignments)
    renamed_labels = Map.get(payload, "renamed_labels") || Map.get(payload, :renamed_labels) || []

    cond do
      not is_list(assignments) ->
        {:error, :invalid_format}

      not is_list(renamed_labels) ->
        {:error, :invalid_format}

      true ->
        {:ok, %{assignments: assignments, renamed_labels: renamed_labels}}
    end
  end

  defp normalize_clustering_payload(_), do: {:error, :invalid_format}

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
