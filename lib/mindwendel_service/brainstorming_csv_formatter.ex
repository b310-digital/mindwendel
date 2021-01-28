defmodule MindwendelService.BrainstormingCSVFormatter do
  def write(ideas) do
    [["body"]]
    |> Stream.concat(ideas |> Stream.map(&[&1.body]))
    |> CSV.encode()
    |> Enum.sort()
  end
end
