# One-time bootstrap for hosts without shell access (e.g. Render Free).
#
# Creates the admin account on first boot when ADMIN_EMAIL and ADMIN_PASSWORD
# are set in the environment. It is safe to run on every boot: if the account
# already exists it does nothing.
#
# Run order (see render.yaml startCommand):
#   mix ecto.migrate
#   mix run priv/repo/render_bootstrap.exs
#   mix phx.server

alias Xpressbus.Admins

email = System.get_env("ADMIN_EMAIL")
password = System.get_env("ADMIN_PASSWORD")

if is_binary(email) and email != "" and is_binary(password) and password != "" do
  case Admins.get_by_email(email) do
    nil ->
      attrs = %{
        email: email,
        name: System.get_env("ADMIN_NAME", "Administrator"),
        hashed_password: Admins.hash_password(password)
      }

      case Admins.create_admin(attrs) do
        {:ok, admin} ->
          IO.puts("[bootstrap] admin created: #{admin.email}")

        {:error, changeset} ->
          IO.puts("[bootstrap] admin creation failed: #{inspect(changeset.errors)}")
      end

    _admin ->
      IO.puts("[bootstrap] admin already exists: #{email}")
  end
else
  IO.puts("[bootstrap] ADMIN_EMAIL / ADMIN_PASSWORD not set - skipping")
end
