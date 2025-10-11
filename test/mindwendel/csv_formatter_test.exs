defmodule MindwendelServices.CSVFormatter do
  use Mindwendel.DataCase, async: true
  alias Mindwendel.CSVFormatter
  alias Mindwendel.Factory

  setup do
    %{
      idea: Factory.insert!(:idea, brainstorming: Factory.insert!(:brainstorming))
    }
  end

  describe "ideas_to_csv" do
    test "headers present" do
      assert CSVFormatter.ideas_to_csv([]) |> List.first() == "idea,username,likes\r\n"
    end

    test "idea present", %{idea: idea} do
      assert CSVFormatter.ideas_to_csv([idea]) |> List.last() == "Mindwendel!,Anonymous,0\r\n"
    end
  end
end
