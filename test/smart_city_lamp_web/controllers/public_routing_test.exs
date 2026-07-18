defmodule SmartCityLampWeb.PublicRoutingTest do
  use SmartCityLampWeb.ConnCase

  import Phoenix.LiveViewTest

  test "public pages are available without authentication", %{conn: conn} do
    assert {:ok, home, _html} = live(conn, ~p"/")
    assert has_element?(home, "#open-interactive-map")

    assert {:ok, public_map, _html} = live(conn, ~p"/public-map")
    assert has_element?(public_map, "#public-device-map")

    assert html_response(get(conn, ~p"/admin/login"), 200) =~ "admin-login-form"
  end

  test "protected routes redirect anonymous visitors", %{conn: conn} do
    for path <- [~p"/admin/dashboard", ~p"/admin/devices"] do
      conn = get(recycle(conn), path)
      assert redirected_to(conn) == ~p"/admin/login"
    end
  end

  test "authenticated admin can open dashboard", %{conn: conn} do
    admin = create_admin()
    conn = log_in_admin(conn, admin)
    assert {:ok, view, _html} = live(conn, ~p"/admin/dashboard")
    assert has_element?(view, "#device-summary")
  end

  test "public map remains available but simulation controls are unavailable when disabled", %{
    conn: conn
  } do
    device =
      SmartCityLamp.Repo.insert!(%SmartCityLamp.Devices.Device{
        device_code: "LAMP-FLAG-001",
        name: "Flag Lamp",
        latitude: -6.2,
        longitude: 106.8,
        installation_address: "Flag Area",
        installation_date: ~D[2026-01-01],
        firmware_version: "1.0.0"
      })

    previous = Application.get_env(:smart_city_lamp, :enable_public_emulator)
    Application.put_env(:smart_city_lamp, :enable_public_emulator, false)
    on_exit(fn -> Application.put_env(:smart_city_lamp, :enable_public_emulator, previous) end)

    assert {:ok, view, _html} = live(conn, ~p"/public-map")
    render_hook(view, "select_device", %{"id" => device.id})
    assert has_element?(view, "#simulation-unavailable")
    refute has_element?(view, "#drawer-scenario-buttons")
  end
end
