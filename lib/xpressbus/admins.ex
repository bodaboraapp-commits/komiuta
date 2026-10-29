defmodule Xpressbus.Admins do
  @moduledoc """
  The Admins context handles admin authentication.
  """

  alias Xpressbus.Repo
  alias Xpressbus.Admins.Admin

  @doc """
  Gets an admin by email.
  """
  def get_by_email(email), do: Repo.get_by(Admin, email: email)

  @doc """
  Hashes a password using PBKDF2.
  """
  def hash_password(password) when is_binary(password) do
    salt = :crypto.strong_rand_bytes(16)
    dk = :crypto.pbkdf2_hmac(:sha256, password, salt, 100_000, 32)
    Base.encode64(salt <> dk)
  end

  @doc """
  Verifies a password against a stored hash.
  """
  def verify_password(_password, nil), do: false

  def verify_password(password, stored_hash) do
    decoded = Base.decode64!(stored_hash)
    salt = binary_part(decoded, 0, 16)
    dk = binary_part(decoded, 16, 32)
    test_dk = :crypto.pbkdf2_hmac(:sha256, password, salt, 100_000, 32)
    secure_compare(dk, test_dk)
  rescue
    _ -> false
  end

  defp secure_compare(a, b) when byte_size(a) != byte_size(b), do: false
  defp secure_compare(a, b), do: :crypto.hash(:sha256, a) == :crypto.hash(:sha256, b)

  @doc """
  Creates an admin.
  """
  def create_admin(attrs \\ %{}) do
    %Admin{}
    |> Admin.changeset(attrs)
    |> Repo.insert()
  end
end
