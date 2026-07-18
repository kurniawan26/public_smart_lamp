defmodule SmartCityLamp.Accounts.Password do
  @moduledoc false

  @iterations 600_000
  @length 32
  @digest :sha256

  def hash(password) when is_binary(password) do
    salt = :crypto.strong_rand_bytes(16)
    derived = :crypto.pbkdf2_hmac(@digest, password, salt, @iterations, @length)

    Enum.join(
      [
        "pbkdf2_sha256",
        Integer.to_string(@iterations),
        Base.encode64(salt, padding: false),
        Base.encode64(derived, padding: false)
      ],
      "$"
    )
  end

  def verify(password, encoded) when is_binary(password) and is_binary(encoded) do
    with ["pbkdf2_sha256", iterations, salt, expected] <- String.split(encoded, "$"),
         {iterations, ""} <- Integer.parse(iterations),
         {:ok, salt} <- Base.decode64(salt, padding: false),
         {:ok, expected} <- Base.decode64(expected, padding: false) do
      actual = :crypto.pbkdf2_hmac(@digest, password, salt, iterations, byte_size(expected))
      Plug.Crypto.secure_compare(actual, expected)
    else
      _ -> false
    end
  end

  def verify(_, _), do: false

  def no_user_verify(password) when is_binary(password) do
    _ = :crypto.pbkdf2_hmac(@digest, password, <<0::128>>, @iterations, @length)
    false
  end
end
