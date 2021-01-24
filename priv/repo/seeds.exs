# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Mindwendel.Repo.insert!(%Mindwendel.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Mindwendel.Help.Inspiration
alias Mindwendel.Repo

Repo.insert(
  %Inspiration{
    title: "What if superman would face this problem?",
    type: "What if",
    language: "en"
  },
  on_conflict: :nothing
)
