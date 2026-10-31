defmodule Xpressbus.IndexNow do
  @moduledoc """
  IndexNow submission for Komiuta.

  IndexNow is the shared instant-indexing protocol supported by Bing, Yandex,
  Seznam and other engines. The key file is served from the site root as
  `/<key>.txt`; search engines verify ownership by fetching the key location
  included in every submission.

  Submit the sitemap URLs with `mix komiuta.indexnow`, or pass a smaller list
  after publishing new pages.
  """

  @key "9f2c7a4e1b8d6f30c5a9e2b7d4f1a6c3"
  @host "www.komiuta.com"
  @endpoint "https://api.indexnow.org/indexnow"

  def key, do: @key

  def host, do: @host

  def key_location, do: "https://#{@host}/#{@key}.txt"

  def endpoint, do: @endpoint

  @doc "Returns every `<loc>` URL from a sitemap."
  def sitemap_urls(sitemap_url \\ "https://#{@host}/sitemap.xml") do
    case Req.get(sitemap_url, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        Regex.scan(~r/<loc>(.*?)<\/loc>/, body, capture: :all_but_first)
        |> Enum.map(fn [url] -> url |> String.trim() |> decode_entities() end)

      {:ok, %{status: status}} ->
        {:error, {:http, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Submits a list of URLs (max 10,000 per request) to IndexNow."
  def submit(urls) when is_list(urls) and urls != [] do
    body = %{
      host: @host,
      key: @key,
      keyLocation: key_location(),
      urlList: Enum.take(urls, 10_000)
    }

    Req.post(@endpoint,
      json: body,
      headers: [{"content-type", "application/json; charset=utf-8"}],
      receive_timeout: 30_000
    )
  end

  def submit([]), do: {:error, :no_urls}

  defp decode_entities(value) do
    value
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&apos;", "'")
  end
end
