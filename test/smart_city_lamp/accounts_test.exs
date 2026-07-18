defmodule SmartCityLamp.AccountsTest do
  use SmartCityLamp.DataCase

  alias SmartCityLamp.Accounts

  test "admin password is hashed and credentials authenticate" do
    assert {:ok, admin} =
             Accounts.create_admin(%{
               email: "ADMIN@example.test",
               password: "secure-password-123",
               name: "Admin",
               role: :admin
             })

    assert admin.email == "admin@example.test"
    assert admin.hashed_password =~ "pbkdf2_sha256$"
    refute admin.hashed_password =~ "secure-password-123"

    assert {:ok, authenticated} =
             Accounts.authenticate_admin("admin@example.test", "secure-password-123")

    assert authenticated.id == admin.id

    assert {:error, :invalid_credentials} =
             Accounts.authenticate_admin(admin.email, "incorrect-password")
  end

  test "email is unique and password policy is enforced" do
    assert {:error, changeset} =
             Accounts.create_admin(%{
               email: "admin@example.test",
               password: "short",
               name: "Admin"
             })

    assert "should be at least 10 character(s)" in errors_on(changeset).password
  end
end
