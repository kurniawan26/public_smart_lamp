defmodule SmartCityLamp.Repo.Migrations.CreateAdmins do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", "DROP EXTENSION IF EXISTS citext"

    create table(:admins) do
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :name, :string, null: false
      add :role, :string, null: false, default: "ADMIN"
      add :last_login_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:admins, [:email])
    create constraint(:admins, :valid_admin_role, check: "role IN ('ADMIN')")
  end
end
