defmodule Mindwendel.Factory do
  alias Mindwendel.Repo
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Brainstormings.Lane
  alias Mindwendel.Brainstormings.IdeaLabel
  alias Mindwendel.Brainstormings.IdeaIdeaLabel
  alias Mindwendel.Brainstormings.Like
  alias Mindwendel.Attachments.Link
  alias Mindwendel.Accounts.User
  alias Mindwendel.Help.Inspiration

  def build(:brainstorming) do
    %Brainstorming{
      name: "How to brainstorm ideas?",
      # This can be removed as soon the todo is solved in lib/mindwendel/brainstormings/brainstorming.ex:12
      admin_url_id: Ecto.UUID.generate(),
      labels: Brainstorming.idea_label_factory(),
      lanes: [build(:lane)]
    }
  end

  def build(:idea) do
    brainstorming = build(:brainstorming)
    lane = build(:lane)

    %Idea{
      body: "Mindwendel!",
      brainstorming: brainstorming,
      lane: lane
    }
  end

  def build(:idea_label) do
    %IdeaLabel{}
  end

  def build(:idea_idea_label) do
    %IdeaIdeaLabel{}
  end

  def build(:link) do
    %Link{}
  end

  def build(:inspiration) do
    %Inspiration{title: "Hi", type: "test"}
  end

  def build(:like) do
    %Like{}
  end

  def build(:user) do
    %User{}
  end

  def build(:lane) do
    %Lane{}
  end

  def build(:brainstorming, :with_users) do
    %Brainstorming{
      name: "How to brainstorm ideas?",
      users: [build(:user)]
    }
  end

  def build(:like, :with_idea_and_user) do
    %Like{
      user: build(:user),
      idea: build(:idea, brainstorming: build(:brainstorming))
    }
  end

  def build(factory_name, attributes) do
    factory_name |> build() |> struct!(attributes)
  end

  def insert!(:brainstorming, :with_users) do
    build(:brainstorming, :with_users) |> Repo.insert!()
  end

  def insert!(:brainstorming, :with_labels) do
    build(:brainstorming, :with_labels) |> Repo.insert!()
  end

  def insert!(:like, :with_idea_and_user) do
    build(:like, :with_idea_and_user) |> Repo.insert!()
  end

  def insert!(factory_name, attributes) do
    factory_name |> build(attributes) |> Repo.insert!()
  end

  def insert!(factory_name) do
    factory_name |> build() |> Repo.insert!()
  end
end
