defmodule Mindwendel.IdeaTest do
  use Mindwendel.DataCase, async: true
  alias Mindwendel.Factory

  alias Mindwendel.Ideas
  alias Mindwendel.Brainstormings.Idea

  describe("Factory.build(:idea)") do
    setup do
      brainstorming = Factory.insert!(:brainstorming)
      lane = Enum.at(brainstorming.lanes, 0)

      idea =
        Factory.build(:idea, brainstorming_id: brainstorming.id, lane_id: lane.id)

      %{
        brainstorming: brainstorming,
        idea: idea,
        lane: lane
      }
    end

    test "builds object", %{idea: idea} do
      assert idea
    end

    test "builds valid object", %{idea: idea} do
      idea_changeset = Idea.changeset(idea)
      assert idea_changeset.valid?
    end

    test "adds a default position order", %{brainstorming: brainstorming, lane: lane} do
      changeset =
        Idea.changeset(%Idea{}, %{
          brainstorming_id: brainstorming.id,
          lane_id: lane.id,
          body: "test"
        })

      assert changeset.changes.position_order == 1
    end
  end

  describe("Factory.insert!(:idea)") do
    setup do
      %{idea: Factory.insert!(:idea)}
    end

    test "saves without problem", %{idea: idea} do
      assert idea
    end

    test "saves object in database" do
      assert Ideas.list_ideas() |> Enum.count() == 1
    end
  end

  describe "#valid?" do
    setup do
      brainstorming = Factory.insert!(:brainstorming)
      lane = Enum.at(brainstorming.lanes, 0)

      idea =
        Factory.build(:idea,
          brainstorming_id: brainstorming.id,
          brainstorming: brainstorming,
          lane: lane
        )

      %{
        brainstorming: brainstorming,
        idea: idea,
        lane: lane
      }
    end

    # test "require brainstorming", %{idea: idea} do
    #   assert_raise RuntimeError, ~r/:brainstorming/, fn ->
    #     Idea.changeset(idea, %{brainstorming: nil})
    #   end
    # end

    test "require present body", %{idea: idea} do
      refute Idea.changeset(idea, %{body: nil}).valid?
      refute Idea.changeset(idea, %{body: ""}).valid?
      assert Idea.changeset(idea, %{body: "More than two characters"}).valid?
    end
  end

  describe "HTML stripping (XSS prevention)" do
    setup do
      brainstorming = Factory.insert!(:brainstorming)
      lane = Enum.at(brainstorming.lanes, 0)

      %{
        brainstorming: brainstorming,
        lane: lane
      }
    end

    test "strips script tags from body", %{brainstorming: brainstorming, lane: lane} do
      changeset =
        Idea.changeset(%Idea{}, %{
          brainstorming_id: brainstorming.id,
          lane_id: lane.id,
          body: "<script>alert('XSS')</script>Hello World"
        })

      assert changeset.changes.body == "Hello World"
    end

    test "strips img tags with onerror handlers", %{brainstorming: brainstorming, lane: lane} do
      changeset =
        Idea.changeset(%Idea{}, %{
          brainstorming_id: brainstorming.id,
          lane_id: lane.id,
          body: "<img src=x onerror=alert('XSS')>Test idea"
        })

      assert changeset.changes.body == "Test idea"
    end

    test "strips all HTML tags", %{brainstorming: brainstorming, lane: lane} do
      changeset =
        Idea.changeset(%Idea{}, %{
          brainstorming_id: brainstorming.id,
          lane_id: lane.id,
          body: "<div><p>Hello</p><strong>World</strong></div>"
        })

      assert changeset.changes.body == "Hello World"
    end

    test "strips event handlers", %{brainstorming: brainstorming, lane: lane} do
      changeset =
        Idea.changeset(%Idea{}, %{
          brainstorming_id: brainstorming.id,
          lane_id: lane.id,
          body: "<a href='javascript:alert(1)'>Click me</a>"
        })

      assert changeset.changes.body == "Click me"
    end

    test "handles unclosed tags", %{brainstorming: brainstorming, lane: lane} do
      changeset =
        Idea.changeset(%Idea{}, %{
          brainstorming_id: brainstorming.id,
          lane_id: lane.id,
          body: "<div>Unclosed div with <b>bold text"
        })

      # Floki should handle unclosed tags gracefully
      assert String.contains?(changeset.changes.body, "Unclosed div")
      assert String.contains?(changeset.changes.body, "bold text")
      refute String.contains?(changeset.changes.body, "<div>")
      refute String.contains?(changeset.changes.body, "<b>")
    end

    test "handles nested HTML tags", %{brainstorming: brainstorming, lane: lane} do
      changeset =
        Idea.changeset(%Idea{}, %{
          brainstorming_id: brainstorming.id,
          lane_id: lane.id,
          body: "<div><span><a href='#'>Nested</a> content</span></div>"
        })

      assert changeset.changes.body == "Nested content"
    end

    test "preserves plain text without HTML", %{brainstorming: brainstorming, lane: lane} do
      plain_text = "This is a plain text idea"

      changeset =
        Idea.changeset(%Idea{}, %{
          brainstorming_id: brainstorming.id,
          lane_id: lane.id,
          body: plain_text
        })

      assert changeset.changes.body == plain_text
    end

    test "handles mixed content with multiple script tags", %{
      brainstorming: brainstorming,
      lane: lane
    } do
      changeset =
        Idea.changeset(%Idea{}, %{
          brainstorming_id: brainstorming.id,
          lane_id: lane.id,
          body:
            "<script>alert('XSS1')</script>Safe text<script>alert('XSS2')</script> more safe text"
        })

      assert changeset.changes.body == "Safe text more safe text"
    end

    test "strips iframe tags", %{brainstorming: brainstorming, lane: lane} do
      changeset =
        Idea.changeset(%Idea{}, %{
          brainstorming_id: brainstorming.id,
          lane_id: lane.id,
          body: "<iframe src='javascript:alert(1)'></iframe>Text content"
        })

      assert changeset.changes.body == "Text content"
    end

    test "strips svg with onload handler", %{brainstorming: brainstorming, lane: lane} do
      changeset =
        Idea.changeset(%Idea{}, %{
          brainstorming_id: brainstorming.id,
          lane_id: lane.id,
          body: "<svg onload=alert('XSS')></svg>Clean text"
        })

      assert changeset.changes.body == "Clean text"
    end

    test "handles empty body after HTML stripping", %{brainstorming: brainstorming, lane: lane} do
      changeset =
        Idea.changeset(%Idea{}, %{
          brainstorming_id: brainstorming.id,
          lane_id: lane.id,
          body: "<script>alert('XSS')</script>"
        })

      # Should be empty string after stripping, which will fail validation
      refute changeset.valid?
      assert changeset.changes.body == ""
    end

    test "preserves spaces between text in different tags", %{
      brainstorming: brainstorming,
      lane: lane
    } do
      changeset =
        Idea.changeset(%Idea{}, %{
          brainstorming_id: brainstorming.id,
          lane_id: lane.id,
          body: "<p>First paragraph</p><p>Second paragraph</p>"
        })

      # Floki.text with sep: " " should preserve spaces
      assert changeset.changes.body == "First paragraph Second paragraph"
    end

    test "strips HTML when updating an existing idea" do
      idea = Factory.insert!(:idea, body: "Original text")

      changeset =
        Idea.changeset(idea, %{
          body: "<b>Updated</b> with HTML"
        })

      assert changeset.changes.body == "Updated with HTML"
    end

    test "handles body tag with onload", %{brainstorming: brainstorming, lane: lane} do
      changeset =
        Idea.changeset(%Idea{}, %{
          brainstorming_id: brainstorming.id,
          lane_id: lane.id,
          body: "<body onload=alert('XSS')>Body text</body>"
        })

      assert changeset.changes.body == "Body text"
    end
  end

  describe "#update_idea" do
    @describetag :skip

    setup do
      %{idea: Factory.insert!(:idea)}
    end

    test "update idea_labels", %{idea: idea} do
      Ideas.update_idea(idea, %{idea_labels: []})

      assert Enum.empty?(idea.idea_labels)
    end

    @tag :skip
    test "only accepts idea_labels of associated brainstorming"

    @tag :skip
    test "does not save duplicate idea_labels "
  end
end
