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

alias Mindwendel.Help.BrainstormingTechnique
alias Mindwendel.Repo

Repo.insert(
  %BrainstormingTechnique{
    title: "5 Why Method",
    description:
      "Ask yourselve five times, why the given situation is like it is. For example: Why is the car slow? Because the engines performance is weak. Why is the performance weak? ...",
    language: "en"
  },
  on_conflict: :nothing
)

Repo.insert(
  %BrainstormingTechnique{
    title: "What if",
    description:
      "Try looking from a different angle at the problem, by using a different context: What if superman would face this problem? What if the problem would be twice as worse?",
    language: "en"
  },
  on_conflict: :nothing
)
