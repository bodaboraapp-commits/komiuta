defmodule Mix.Tasks.Komiuta.Indexnow do
  @shortdoc "Submits Komiuta sitemap URLs to IndexNow (Bing, Yandex, etc.)"

  @moduledoc """
  Sends the URLs from the live sitemap to IndexNow.

      mix komiuta.indexnow
      mix komiuta.indexnow --dry-run
      mix komiuta.indexnow --sitemap https://www.komiuta.com/sitemap.xml
  """

  use Mix.Task

  @impl true
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [dry_run: :boolean, sitemap: :string, url: :keep]
      )

    Application.ensure_all_started(:req)

    sitemap = opts[:sitemap] || "https://www.komiuta.com/sitemap.xml"
    extra_urls = Keyword.get_values(opts, :url)

    Mix.shell().info("Fetching #{sitemap} …")

    case Xpressbus.IndexNow.sitemap_urls(sitemap) do
      {:error, reason} ->
        Mix.raise("Could not read sitemap: #{inspect(reason)}")

      urls ->
        urls = Enum.uniq(urls ++ extra_urls)

        if opts[:dry_run] do
          Mix.shell().info("Dry run: #{length(urls)} URLs would be submitted.")
          Enum.each(urls, &Mix.shell().info("  " <> &1))
        else
          submit(urls)
        end
    end
  end

  defp submit(urls) do
    Mix.shell().info("Submitting #{length(urls)} URLs to IndexNow …")

    case Xpressbus.IndexNow.submit(urls) do
      {:ok, %{status: status, body: body}} when status in [200, 202] ->
        Mix.shell().info("IndexNow accepted the submission (HTTP #{status}). #{inspect(body)}")

      {:ok, %{status: status, body: body}} ->
        Mix.raise("IndexNow rejected the submission: HTTP #{status} #{inspect(body)}")

      {:error, reason} ->
        Mix.raise("IndexNow request failed: #{inspect(reason)}")
    end
  end
end
