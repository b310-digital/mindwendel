defmodule Mindwendel.CSVFormatter do
  alias Mindwendel.Likes

  def ideas_to_csv(ideas) do
    [["idea", "username", "likes"]]
    |> Stream.concat(
      ideas
      |> Stream.map(
        &[
          &1.body,
          Gettext.gettext(MindwendelWeb.Gettext, &1.username),
          Likes.count_likes_for_idea(&1)
        ]
      )
    )
    |> CSV.encode()
    |> Enum.to_list()
  end
end
