defmodule MindwendelService.SessionService do
  @moduledoc false

  @session_key_user_id :current_user_id

  def session_key_current_user_id, do: @session_key_user_id

  def get_current_user_id(%Plug.Conn{} = conn) do
    conn |> Plug.Conn.get_session() |> get_current_user_id()
  end

  def get_current_user_id(session) do
    session |> Map.get(Atom.to_string(@session_key_user_id))
  end

  def set_current_user_id(%Plug.Conn{} = conn) do
    Plug.Conn.put_session(conn, @session_key_user_id, generate_user_id())
  end

  defp generate_user_id do
    Ecto.UUID.generate()
  end
end
