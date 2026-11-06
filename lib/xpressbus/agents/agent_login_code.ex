defmodule Xpressbus.Agents.AgentLoginCode do
  @moduledoc """
  A single-use email one-time code for an agent application login.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "agent_login_codes" do
    belongs_to(:agent_application, Xpressbus.Agents.AgentApplication, type: :binary_id)

    field(:code_digest, :string)
    field(:expires_at, :utc_datetime)
    field(:attempts, :integer, default: 0)
    field(:consumed_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  def changeset(login_code, attrs) do
    login_code
    |> cast(attrs, [:agent_application_id, :code_digest, :expires_at, :attempts, :consumed_at])
    |> validate_required([:agent_application_id, :code_digest, :expires_at])
  end
end
