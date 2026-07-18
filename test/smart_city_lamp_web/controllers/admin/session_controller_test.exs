defmodule SmartCityLampWeb.Admin.SessionControllerTest do
  use SmartCityLampWeb.ConnCase

  test "valid credentials renew the session and log in", %{conn: conn} do
    admin = create_admin(%{email: "login@example.test", password: "correct-password-123"})
    conn = init_test_session(conn, %{previous: "value"})

    conn =
      post(conn, ~p"/admin/login", %{
        "admin" => %{"email" => admin.email, "password" => "correct-password-123"}
      })

    assert redirected_to(conn) == ~p"/admin/dashboard"
    assert get_session(conn, :admin_id) == admin.id
    assert conn.private.plug_session_info == :renew
    assert SmartCityLamp.Accounts.get_admin(admin.id).last_login_at
  end

  test "invalid credentials are rejected", %{conn: conn} do
    admin = create_admin(%{email: "invalid@example.test"})

    conn =
      post(conn, ~p"/admin/login", %{
        "admin" => %{"email" => admin.email, "password" => "wrong-password"}
      })

    assert html_response(conn, 422) =~ "Invalid email or password"
    refute get_session(conn, :admin_id)
  end

  test "logout clears the session", %{conn: conn} do
    admin = create_admin()
    conn = conn |> log_in_admin(admin) |> delete(~p"/admin/logout")
    assert redirected_to(conn) == ~p"/admin/login"
    assert conn.private.plug_session_info == :drop
  end

  test "logged in admin is redirected away from login", %{conn: conn} do
    admin = create_admin()
    conn = conn |> log_in_admin(admin) |> get(~p"/admin/login")
    assert redirected_to(conn) == ~p"/admin/dashboard"
  end
end
