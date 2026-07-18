defmodule SmartCityLamp.Accounts do
  import Ecto.Query, warn: false

  alias SmartCityLamp.Accounts.Admin
  alias SmartCityLamp.Accounts.Password
  alias SmartCityLamp.Repo

  def get_admin(nil), do: nil
  def get_admin(id), do: Repo.get(Admin, id)

  def get_admin_by_email(email) when is_binary(email) do
    normalized = email |> String.trim() |> String.downcase()
    Repo.one(from admin in Admin, where: admin.email == ^normalized)
  end

  def get_admin_by_email(_email), do: nil

  def create_admin(attrs), do: %Admin{} |> Admin.create_changeset(attrs) |> Repo.insert()

  def authenticate_admin(email, password) when is_binary(email) and is_binary(password) do
    case get_admin_by_email(email) do
      %Admin{} = admin ->
        if Password.verify(password, admin.hashed_password),
          do: {:ok, admin},
          else: {:error, :invalid_credentials}

      nil ->
        Password.no_user_verify(password)
        {:error, :invalid_credentials}
    end
  end

  def authenticate_admin(_, _), do: {:error, :invalid_credentials}

  def record_login(%Admin{} = admin) do
    admin
    |> Ecto.Changeset.change(last_login_at: DateTime.utc_now())
    |> Repo.update()
  end
end
