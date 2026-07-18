defmodule SmartCityLampWeb.ConnCase do
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
  by setting `use SmartCityLampWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint SmartCityLampWeb.Endpoint

      use SmartCityLampWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import SmartCityLampWeb.ConnCase
    end
  end

  setup tags do
    SmartCityLamp.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def create_admin(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    defaults = %{
      email: "admin-#{unique}@example.test",
      password: "valid-password-123",
      name: "Test Administrator",
      role: :admin
    }

    {:ok, admin} = SmartCityLamp.Accounts.create_admin(Map.merge(defaults, attrs))
    admin
  end

  def log_in_admin(conn, admin) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:admin_id, admin.id)
  end
end
