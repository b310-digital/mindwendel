defmodule MindwendelWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use MindwendelWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate
  import Mox
  alias Ecto.Adapters.SQL.Sandbox
  alias Mindwendel.Repo
  alias Phoenix.ConnTest

  using do
    quote do
      use MindwendelWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import MindwendelWeb.ConnCase

      # Import Mox for tests that need to override AI behavior
      import Mox

      # The default endpoint for testing
      @endpoint MindwendelWeb.Endpoint
    end
  end

  # Set up Mox properly for all conn tests
  setup :set_mox_from_context
  setup :verify_on_exit!
  setup :setup_ai_disabled_stub

  setup tags do
    :ok = Sandbox.checkout(Repo)

    unless tags[:async] do
      Sandbox.mode(Repo, {:shared, self()})
    end

    {:ok, conn: ConnTest.build_conn()}
  end

  # Provide default AI disabled stub for all ConnCase tests
  # This prevents Mox.UnexpectedCallError when LiveViews render
  defp setup_ai_disabled_stub(_context) do
    Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
    |> Mox.stub(:enabled?, fn -> false end)
    |> Mox.stub(:generate_ideas, fn _title, _lanes, _existing_ideas, _locale ->
      {:error, :ai_not_enabled}
    end)

    :ok
  end
end
