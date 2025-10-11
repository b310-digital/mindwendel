defmodule Mindwendel.Plugs.SetSessionUserId do
  alias Mindwendel.Services.SessionService

  # @impl true
  def init(opts) do
    opts
  end

  # @impl true
  def call(conn, _opts) do
    case SessionService.get_current_user_id(conn) do
      nil ->
        SessionService.set_current_user_id(conn)

      _ ->
        conn
    end
  end
end
