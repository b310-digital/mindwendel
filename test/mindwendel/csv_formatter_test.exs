defmodule MindwendelServices.CSVFormatter do
  use Mindwendel.DataCase, async: true
  alias Mindwendel.CSVFormatter
  alias Mindwendel.Factory

  setup do
    brainstorming = Factory.insert!(:brainstorming)
    lane = List.first(brainstorming.lanes)
    idea = Factory.insert!(:idea, brainstorming: brainstorming, lane: lane)

    %{brainstorming: brainstorming, lane: lane, idea: idea}
  end

  describe "brainstorming_to_csv" do
    test "headers present", %{brainstorming: brainstorming} do
      brainstorming = preload_brainstorming(brainstorming)

      assert CSVFormatter.brainstorming_to_csv(brainstorming) |> List.first() ==
               "lane,idea,username,likes,labels,comments,files,link_url\r\n"
    end

    test "idea present with lane", %{brainstorming: brainstorming} do
      brainstorming = preload_brainstorming(brainstorming)
      csv = CSVFormatter.brainstorming_to_csv(brainstorming)

      assert List.last(csv) =~ "Mindwendel!"
      assert List.last(csv) =~ "Anonymous"
    end

    test "idea with labels", %{brainstorming: brainstorming, idea: idea} do
      label = List.first(brainstorming.labels)

      Factory.insert!(:idea_idea_label,
        idea_id: idea.id,
        idea_label_id: label.id
      )

      brainstorming = preload_brainstorming(brainstorming)
      csv = CSVFormatter.brainstorming_to_csv(brainstorming) |> Enum.join()

      assert csv =~ label.name
    end

    test "idea with comments", %{brainstorming: brainstorming, idea: idea} do
      user = Factory.insert!(:user)

      Factory.insert!(:comment,
        body: "Great idea!",
        username: "Tester",
        idea: idea,
        user: user
      )

      brainstorming = preload_brainstorming(brainstorming)
      csv = CSVFormatter.brainstorming_to_csv(brainstorming) |> Enum.join()

      assert csv =~ "Great idea!"
      assert csv =~ "Tester"
    end

    test "idea with link", %{brainstorming: brainstorming, idea: idea} do
      Factory.insert!(:link,
        url: "https://example.com",
        title: "Example",
        idea: idea
      )

      brainstorming = preload_brainstorming(brainstorming)
      csv = CSVFormatter.brainstorming_to_csv(brainstorming) |> Enum.join()

      assert csv =~ "https://example.com"
    end

    test "empty brainstorming has only headers" do
      empty_brainstorming = Factory.insert!(:brainstorming)
      empty_brainstorming = preload_brainstorming(empty_brainstorming)
      csv = CSVFormatter.brainstorming_to_csv(empty_brainstorming)

      assert length(csv) == 1
      assert List.first(csv) =~ "lane,idea,username"
    end
  end

  defp preload_brainstorming(brainstorming) do
    import Ecto.Query

    Mindwendel.Repo.preload(
      brainstorming,
      [
        lanes:
          {from(l in Mindwendel.Brainstormings.Lane, order_by: [asc: l.position_order]),
           ideas:
             {from(i in Mindwendel.Brainstormings.Idea,
                order_by: [asc_nulls_last: i.position_order, asc: i.inserted_at]
              ), [:link, :likes, :idea_labels, :comments, :files]}}
      ],
      force: true
    )
  end
end
