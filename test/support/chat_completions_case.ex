defmodule Mindwendel.ChatCompletionsCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the API for TTS.
  """
  import Mox

  use ExUnit.CaseTemplate

  using do
    quote do
      import Mindwendel.ChatCompletionsCase

      import Mox
      setup :verify_on_exit!
    end
  end

  def disable_ai() do
    Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
    |> stub(:enabled?, fn ->
      false
    end)

    :ok
  end

  def mock_ai_enabled?(enabled) do
    Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
    |> expect(:enabled?, fn ->
      enabled
    end)
  end

  def mock_generate_ideas(idea_count \\ 3) do
    Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
    |> expect(:generate_ideas, fn title ->
      Enum.map(1..idea_count, fn x ->
        %{"idea" => "#{title} - #{x}"}
      end)
    end)
  end
end
