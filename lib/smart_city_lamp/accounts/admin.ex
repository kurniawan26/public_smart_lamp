defmodule SmartCityLamp.Accounts.Admin do
  use Ecto.Schema
  import Ecto.Changeset

  @roles [admin: "ADMIN"]

  schema "admins" do
    field :email, :string
    field :hashed_password, :string, redact: true
    field :password, :string, virtual: true, redact: true
    field :name, :string
    field :role, Ecto.Enum, values: @roles, default: :admin
    field :last_login_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def create_changeset(admin, attrs) do
    admin
    |> cast(attrs, [:email, :name, :role, :password])
    |> update_change(:email, &normalize_email/1)
    |> validate_required([:email, :name, :role, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_length(:password, min: 10, max: 72)
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  defp normalize_email(email), do: email |> String.trim() |> String.downcase()

  defp put_password_hash(%Ecto.Changeset{valid?: true} = changeset) do
    password = Ecto.Changeset.get_change(changeset, :password)
    put_change(changeset, :hashed_password, SmartCityLamp.Accounts.Password.hash(password))
  end

  defp put_password_hash(changeset), do: changeset
end
