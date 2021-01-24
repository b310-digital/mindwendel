defmodule Mindwendel.Factory do
  alias Mindwendel.Repo
  alias Mindwendel.Brainstormings.Brainstorming
  alias Mindwendel.Brainstormings.Idea
  alias Mindwendel.Brainstormings.Like
  alias Mindwendel.Accounts.User
  alias Mindwendel.Help.BrainstormingTechnique

  def build(:user) do
    %User{}
  end

  def build(:brainstorming) do
    %Brainstorming{
      name: "How to brainstorm ideas?"
    }
  end

  def build(:idea) do
    %Idea{
      body: "Mindwendel!"
    }
  end

  def build(:like) do
    %Like{}
  end

  def build(:brainstorming_technique) do
    %BrainstormingTechnique{title: "Hi", description: "test"}
  end

  def build(:brainstorming, :with_users) do
    %Brainstorming{
      name: "How to brainstorm ideas?",
      users: [build(:user)]
    }
  end

  # TODO: extract to helper
  def build(factory_name, attributes) do
    factory_name |> build() |> struct!(attributes)
  end

  def insert!(:brainstorming, :with_users) do
    build(:brainstorming, :with_users) |> Repo.insert!()
  end

  def insert!(factory_name, attributes) do
    factory_name |> build(attributes) |> Repo.insert!()
  end

  def insert!(factory_name) do
    factory_name |> build() |> Repo.insert!()
  end
end
