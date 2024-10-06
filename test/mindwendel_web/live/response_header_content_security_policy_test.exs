defmodule MindwendelWeb.ResponseHeaderContentSecurityPolicyTest do
  use MindwendelWeb.ConnCase

  alias Mindwendel.Factory

  setup do
    %{
      brainstorming: Factory.insert!(:brainstorming)
    }
  end

  describe "csp directive 'default-src'" do
    test "allows nothing by default for security reasons", %{
      conn: conn,
      brainstorming: brainstorming
    } do
      conn_response = get(conn, ~p"/brainstormings/#{brainstorming.id}")

      assert conn_response
             |> get_resp_header("content-security-policy")
             |> List.first() =~ ~r/(default-src)\s+('none') ;/
    end
  end

  describe "csp directive 'connect-src'" do
    test "allows websocket connection only to itself", %{
      conn: conn,
      brainstorming: brainstorming
    } do
      conn_response = get(conn, ~p"/brainstormings/#{brainstorming.id}")

      assert conn_response
             |> get_resp_header("content-security-policy")
             |> List.first() =~ ~r/(connect-src)\s+('self')/
    end

    test "allows websocket connection to specific websocket endpoint (defined in test environment) to support live views and in all browsers",
         %{
           conn: conn,
           brainstorming: brainstorming
         } do
      conn_response = get(conn, ~p"/brainstormings/#{brainstorming.id}")

      assert conn_response
             |> get_resp_header("content-security-policy")
             |> List.first() =~ ~r/(connect-src)\s+'self' (wss:\/\/localhost) ;/
    end
  end

  describe "csp directive 'img-src'" do
    test "allows image resources via 'http' and 'https' and from anywhere to support preview link image feature",
         %{
           conn: conn,
           brainstorming: brainstorming
         } do
      conn_response = get(conn, ~p"/brainstormings/#{brainstorming.id}")

      assert conn_response
             |> get_resp_header("content-security-policy")
             |> List.first() =~ ~r/(img-src)\s+('self' data: https:) ;/
    end
  end

  describe "csp directive 'script-src'" do
    test "allows only self in prod",
         %{
           conn: conn,
           brainstorming: brainstorming
         } do
      conn_response = get(conn, ~p"/brainstormings/#{brainstorming.id}")

      assert conn_response
             |> get_resp_header("content-security-policy")
             |> List.first() =~ ~r/(script-src)\s+('self') ;/
    end
  end

  describe "csp directive 'style-src'" do
    test "allows only self in prod",
         %{
           conn: conn,
           brainstorming: brainstorming
         } do
      conn_response = get(conn, ~p"/brainstormings/#{brainstorming.id}")

      assert conn_response
             |> get_resp_header("content-security-policy")
             |> List.first() =~ ~r/(style-src)\s+('self') ;/
    end
  end
end
