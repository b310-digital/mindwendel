defmodule Mindwendel.Services.IdeaService do
  @moduledoc """
  Service for AI-powered idea generation in brainstorming sessions.

  This module provides functionality to generate ideas using an LLM
  and automatically add them to brainstorming sessions.
  """

  alias Mindwendel.Ideas
  alias Mindwendel.Services.ChatCompletions.ChatCompletionsService

  require Logger

  @ai_username "AI"

  @doc """
  Checks if AI-powered idea generation is enabled.

  Returns `true` if the feature is enabled via configuration, `false` otherwise.
  """
  @spec idea_generation_enabled?() :: boolean()
  def idea_generation_enabled? do
    ChatCompletionsService.enabled?()
  end

  @doc """
  Generates and adds AI ideas to a brainstorming session.

  ## Parameters
    - brainstorming: The brainstorming struct to add ideas to (must have lanes preloaded)

  ## Returns
    - `{:ok, [idea]}` - List of successfully created ideas
    - `{:ok, []}` - Empty list if AI is disabled or no ideas generated
    - `{:error, reason}` - Error if generation fails
  """
  @spec add_ideas_to_brainstorming(Mindwendel.Brainstormings.Brainstorming.t()) ::
          {:ok, list(Mindwendel.Brainstormings.Idea.t())} | {:error, atom()}
  def add_ideas_to_brainstorming(brainstorming) do
    if idea_generation_enabled?() do
      # Get current locale from Gettext for language-specific idea generation
      locale = Gettext.get_locale(MindwendelWeb.Gettext)

      # Get existing ideas to avoid duplicates
      existing_ideas = Ideas.list_ideas_for_brainstorming(brainstorming.id)

      with {:ok, default_lane_id} <- get_first_lane_id(brainstorming),
           {:ok, generated_ideas} <-
             ChatCompletionsService.generate_ideas(
               brainstorming.name,
               brainstorming.lanes,
               existing_ideas,
               locale
             ) do
        # Build a map of valid lane IDs for quick lookup
        valid_lane_ids = MapSet.new(Enum.map(brainstorming.lanes, & &1.id))

        results =
          Enum.map(generated_ideas, fn generated_idea ->
            # Use the lane_id from AI if valid, otherwise fall back to default
            lane_id = resolve_lane_id(generated_idea["lane_id"], valid_lane_ids, default_lane_id)

            Ideas.create_idea(%{
              username: @ai_username,
              body: generated_idea["idea"],
              brainstorming_id: brainstorming.id,
              lane_id: lane_id
            })
          end)

        # Filter out failed creations and return only successful ones
        {successful, failed} = Enum.split_with(results, &match?({:ok, _}, &1))

        unless Enum.empty?(failed) do
          Logger.warning(
            "Failed to create #{length(failed)} ideas for brainstorming #{brainstorming.id}: #{inspect(failed)}"
          )
        end

        successful_ideas = Enum.map(successful, fn {:ok, idea} -> idea end)
        {:ok, successful_ideas}
      else
        {:error, reason} ->
          Logger.warning("Failed to generate ideas: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:ok, []}
    end
  end

  defp resolve_lane_id(nil, _valid_lane_ids, default_lane_id), do: default_lane_id

  defp resolve_lane_id(lane_id, valid_lane_ids, default_lane_id) do
    if MapSet.member?(valid_lane_ids, lane_id) do
      lane_id
    else
      Logger.debug("AI returned invalid lane_id #{lane_id}, using default lane")
      default_lane_id
    end
  end

  defp get_first_lane_id(brainstorming) do
    case brainstorming.lanes do
      [first_lane | _] -> {:ok, first_lane.id}
      [] -> {:error, :no_lanes_available}
    end
  end
end
