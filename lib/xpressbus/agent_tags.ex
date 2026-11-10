defmodule Xpressbus.AgentTags do
  @moduledoc """
  Signed, printable verification tags for approved KOMIUTA agents.

  The tag is not stored in the database: the printed QR code carries a signed
  token containing the agent application id. Scanning it opens the public
  verification page, which re-checks the live approval status before confirming
  the agent.
  """

  alias Xpressbus.Agents.AgentApplication
  alias XpressbusWeb.Endpoint

  @salt "komiuta-verified-agent-tag-v1"
  @max_age 60 * 60 * 24 * 365 * 5

  @doc "Signs a verification token for an approved agent application."
  def token(%AgentApplication{id: id}), do: Phoenix.Token.sign(Endpoint, @salt, id)

  @doc "Returns the application id for a valid tag token."
  def verify(token) when is_binary(token) do
    Phoenix.Token.verify(Endpoint, @salt, token, max_age: @max_age)
  end

  @doc "Absolute URL encoded in the printed QR code."
  def verify_url(%AgentApplication{} = application) do
    Endpoint.url() <> "/agent/verified/" <> token(application)
  end

  @doc "Initials shown in the agent monogram."
  def initials(%AgentApplication{} = application) do
    application.full_name
    |> to_string()
    |> String.trim()
    |> String.split(~r/\s+/, trim: true)
    |> case do
      [] -> "KA"
      [name] -> String.first(name) |> String.upcase()
      [first, last | _] -> (String.first(first) <> String.first(last)) |> String.upcase()
    end
  end

  @doc "The approval date printed on the tag, or the last update when not reviewed."
  def issued_on(%AgentApplication{} = application) do
    application.reviewed_at || application.updated_at || application.inserted_at
  end
end
