defmodule Mindwendel.HelpTest do
  use Mindwendel.DataCase, async: true
  alias Mindwendel.Factory
  alias Mindwendel.Help

  setup do
    %{inspiration: Factory.insert!(:inspiration)}
  end

  describe "random_inspiration" do
    test "retrieve an inspiration" do
      inspiration = Help.random_inspiration()
      assert !is_nil(inspiration)
    end
  end
end
