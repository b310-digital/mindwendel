defmodule Mindwendel.HelpTest do
  use Mindwendel.DataCase
  alias Mindwendel.Factory
  alias Mindwendel.Help

  setup do
    %{technique: Factory.insert!(:brainstorming_technique)}
  end

  describe "random_brainstorming_technique" do
    test "retrieve a technique" do
      technique = Help.random_brainstorming_technique()
      assert !is_nil(technique)
    end
  end
end
