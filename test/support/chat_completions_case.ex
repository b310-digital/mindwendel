defmodule Mindwendel.ChatCompletionsCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the ChatCompletions mock.

  The mock is configured globally in test_helper.exs.
  This case template sets up per-test stubs and provides helper functions.

  All tests using this case automatically get AI disabled by default.
  Use the helper functions to enable AI or mock specific behaviors.
  """
  import Mox

  use ExUnit.CaseTemplate

  using do
    quote do
      import Mindwendel.ChatCompletionsCase
      import Mox
    end
  end

  setup :set_mox_from_context
  setup :verify_on_exit!
  setup :setup_ai_disabled_stub

  # Default stub: AI is disabled
  # Tests can override this with expect() for specific behavior
  def setup_ai_disabled_stub(_context) do
    Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
    |> stub(:enabled?, fn -> false end)
    |> stub(:generate_ideas, fn _title, _lanes, _existing_ideas, _locale ->
      {:error, :ai_not_enabled}
    end)

    :ok
  end

  # Helper to explicitly stub AI as disabled (for clarity in tests)
  def disable_ai() do
    # Already stubbed in setup, but this allows explicit calls
    Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
    |> stub(:enabled?, fn -> false end)
    |> stub(:generate_ideas, fn _title, _lanes, _existing_ideas, _locale ->
      {:error, :ai_not_enabled}
    end)

    :ok
  end

  # Helper to set up AI enabled with specific expectations
  def mock_ai_enabled?(enabled) do
    Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
    |> expect(:enabled?, fn -> enabled end)
  end

  def mock_generate_ideas(idea_count \\ 3) do
    Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
    |> expect(:generate_ideas, fn title, _lanes, _existing_ideas, _locale ->
      {:ok,
       Enum.map(1..idea_count, fn x ->
         %{"idea" => "#{title} - #{x}"}
       end)}
    end)
  end

  def mock_generate_ideas_error(error_reason \\ :api_error) do
    Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
    |> expect(:generate_ideas, fn _title, _lanes, _existing_ideas, _locale ->
      {:error, error_reason}
    end)
  end
end
