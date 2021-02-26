defmodule Mindwendel.Plugs.XFrameOptions do
  @moduledoc """
  Allows affected ressources to be opened as an iframe by slides.com.
  """
  alias Plug.Conn

  def init(opts \\ %{}), do: Enum.into(opts, %{})

  def call(conn, _opts) do
    Conn.put_resp_header(conn,"x-frame-options","ALLOW-FROM https://slides.com")
  end
end
