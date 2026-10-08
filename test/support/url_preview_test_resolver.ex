defmodule Mindwendel.UrlPreviewTestResolver do
  @moduledoc """
  Resolver for `Mindwendel.UrlPreview` in tests (see config/test.exs).

  Only localhost resolves (Bypass listens there), every other host fails
  without a DNS query, so tests can never reach real servers.
  """

  def resolve("localhost"), do: {:ok, [{127, 0, 0, 1}]}
  def resolve(_host), do: {:error, :nxdomain}
end
