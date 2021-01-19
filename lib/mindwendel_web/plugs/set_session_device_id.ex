defmodule Mindwendel.Plugs.SetSessionUserId do
  # @impl true
  def init(opts) do
    opts
  end

  # @impl true
  def call(conn, _opts) do
    case MindwendelService.SessionService.get_current_user_id(conn) do
      nil ->
        MindwendelService.SessionService.set_current_user_id(conn)

      _ ->
        conn
    end
  end
end
