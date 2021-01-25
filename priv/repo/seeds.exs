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
    title: "What if a super hero would face this problem?",
    type: "What if",
    language: "en"
  },
  on_conflict: :nothing
)

Repo.insert(
  %Inspiration{
    title: "How would Leonardo DaVinci solve this problem?",
    type: "What if",
    language: "en"
  },
  on_conflict: :nothing
)

Repo.insert(
  %Inspiration{
    title: "What would a royal secret agent do?",
    type: "What if",
    language: "en"
  },
  on_conflict: :nothing
)

Repo.insert(
  %Inspiration{
    title: "What would a rich tech entrepreneur do?",
    type: "What if",
    language: "en"
  },
  on_conflict: :nothing
)

Repo.insert(
  %Inspiration{
    title: "How would you solve the problem in the 17th century?",
    type: "What if",
    language: "en"
  },
  on_conflict: :nothing
)

Repo.insert(
  %Inspiration{
    title: "What if you have a billion dollars?",
    type: "What if",
    language: "en"
  },
  on_conflict: :nothing
)

Repo.insert(
  %Inspiration{
    title: "What if you could move with the speed of light?",
    type: "What if",
    language: "en"
  },
  on_conflict: :nothing
)

Repo.insert(
  %Inspiration{
    title: "What if the problem would be twice as worse?",
    type: "What if",
    language: "en"
  },
  on_conflict: :nothing
)
