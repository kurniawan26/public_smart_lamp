defmodule SmartCityLampWeb.Admin.SessionController do
  use SmartCityLampWeb, :controller

  alias SmartCityLamp.Accounts

  def new(conn, _params) do
    render(conn, :new, form: Phoenix.Component.to_form(%{"email" => ""}, as: :admin))
  end

  def create(conn, %{"admin" => %{"email" => email, "password" => password}}) do
    case Accounts.authenticate_admin(email, password) do
      {:ok, admin} ->
        {:ok, admin} = Accounts.record_login(admin)

        conn
        |> configure_session(renew: true)
        |> put_session(:admin_id, admin.id)
        |> put_flash(:info, "Welcome back, #{admin.name}.")
        |> redirect(to: ~p"/admin/dashboard")

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> put_status(:unprocessable_entity)
        |> render(:new, form: Phoenix.Component.to_form(%{"email" => email}, as: :admin))
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Email and password are required.")
    |> put_status(:unprocessable_entity)
    |> render(:new, form: Phoenix.Component.to_form(%{"email" => ""}, as: :admin))
  end

  def delete(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/admin/login")
  end
end
