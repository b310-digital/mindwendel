defmodule MindwendelService.BrainstormingCSVFormatter do
  alias Mindwendel.Brainstormings

  def write(ideas) do
    [["idea", "username", "likes"]]
    |> Stream.concat(
      ideas
      |> Stream.map(&[&1.body, &1.username, Brainstormings.count_likes_for_idea(&1)])
    )
    |> CSV.encode(separator: ?;)
    |> Enum.to_list()
  end
end
