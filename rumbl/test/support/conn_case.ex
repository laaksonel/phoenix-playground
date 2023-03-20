defmodule RumblWeb.ConnCase do
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
  by setting `use RumblWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint RumblWeb.Endpoint

      use RumblWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import RumblWeb.ConnCase
    end
  end

  setup tags do
    Rumbl.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that registers and logs in users2.

      setup :register_and_log_in_user2

  It stores an updated connection and a registered user2 in the
  test context.
  """
  def register_and_log_in_user2(%{conn: conn}) do
    user2 = Rumbl.Accounts2Fixtures.user2_fixture()
    %{conn: log_in_user2(conn, user2), user2: user2}
  end

  @doc """
  Logs the given `user2` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user2(conn, user2) do
    token = Rumbl.Accounts2.generate_user2_session_token(user2)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user2_token, token)
  end
end
