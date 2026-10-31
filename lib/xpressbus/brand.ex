defmodule Xpressbus.Brand do
  @moduledoc """
  Single source of truth for public brand, contact and social details.

  Used by the website footer and transactional email so the website, support
  contacts and social handles only need updating in one place. Configure in
  `config/config.exs` under `config :xpressbus, :brand`.
  """

  @defaults %{
    website: "https://www.komiuta.com",
    email: "hello@komiuta.com",
    phone: "0800 211 211",
    phone_uri: "tel:0800211211",
    social_links: [
      %{name: "Facebook", url: "https://www.facebook.com/komiuta"},
      %{name: "Instagram", url: "https://www.instagram.com/komiuta"},
      %{name: "X", url: "https://x.com/komiuta"},
      %{name: "TikTok", url: "https://www.tiktok.com/@komiuta"}
    ]
  }

  @doc "Public website URL, including the scheme."
  def website, do: get(:website)

  @doc "Website text without the scheme, for display in footers."
  def website_label do
    website()
    |> String.replace_prefix("https://", "")
    |> String.replace_prefix("http://", "")
  end

  @doc "Support email address."
  def email, do: get(:email)

  @doc "Support phone number as displayed."
  def phone, do: get(:phone)

  @doc "Support phone URI for tel: links."
  def phone_uri, do: get(:phone_uri)

  @doc "List of %{name: ..., url: ...} social links."
  def social_links, do: get(:social_links)

  defp get(key) do
    :xpressbus
    |> Application.get_env(:brand, %{})
    |> Map.get(key, Map.fetch!(@defaults, key))
  end
end
