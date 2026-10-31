defmodule Mix.Tasks.Komiuta.ValidateSchema do
  @shortdoc "Validates JSON-LD, canonical and metadata on live SEO pages"

  @moduledoc """
  Fetches the live sitemap (or a custom URL) and validates the structured data
  used by Google, Bing and AI answer engines.

      mix komiuta.validate_schema
      mix komiuta.validate_schema --sitemap https://www.komiuta.com/sitemap.xml
  """

  use Mix.Task

  @required %{
    "Organization" => ["name", "url"],
    "WebSite" => ["name", "url"],
    "BusTrip" => ["name", "provider", "departureBusStop", "arrivalBusStop", "offers"],
    "Offer" => ["price", "priceCurrency", "availability"],
    "FAQPage" => ["mainEntity"],
    "Question" => ["name", "acceptedAnswer"],
    "Answer" => ["text"],
    "BreadcrumbList" => ["itemListElement"],
    "ListItem" => ["position", "name"],
    "BlogPosting" => ["headline", "datePublished", "author", "publisher", "mainEntityOfPage"],
    "AboutPage" => ["name", "url"],
    "ItemList" => ["itemListElement"],
    "Blog" => ["name", "url"]
  }

  @impl true
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [sitemap: :string, base: :string])
    Application.ensure_all_started(:req)

    sitemap = opts[:sitemap] || "https://www.komiuta.com/sitemap.xml"

    urls =
      case Req.get(sitemap, receive_timeout: 30_000) do
        {:ok, %{status: 200, body: body}} ->
          Regex.scan(~r/<loc>(.*?)<\/loc>/, body, capture: :all_but_first)
          |> Enum.map(fn [url] -> String.trim(url) end)

        other ->
          Mix.raise("Could not fetch sitemap: #{inspect(other)}")
      end

    Mix.shell().info("Validating #{length(urls)} pages from #{sitemap} …")

    base = opts[:base]

    targets =
      if base do
        Enum.map(urls, fn url ->
          String.replace(url, ~r{^https?://[^/]+}, String.trim_trailing(base, "/"))
        end)
      else
        urls
      end

    results =
      Enum.zip(targets, urls)
      |> Enum.map(fn {target, source} ->
        case validate_url(target) do
          :ok -> :ok
          {_, reasons} -> {source, reasons}
        end
      end)

    failures = Enum.reject(results, &(&1 == :ok))

    if failures == [] do
      Mix.shell().info("PASS — all pages have valid JSON-LD, canonical and title/description.")
    else
      Mix.shell().error("FAIL — #{length(failures)} page(s) have schema/metadata issues:")

      Enum.each(failures, fn {url, reasons} ->
        Mix.shell().error("  #{url}")
        Enum.each(reasons, &Mix.shell().error("    - #{&1}"))
      end)

      Mix.raise("Schema validation failed")
    end
  end

  defp validate_url(url) do
    case Req.get(url, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        case check(body) do
          :ok -> :ok
          {:error, reasons} -> {url, reasons}
        end

      _ ->
        {url, ["page did not return 200"]}
    end
  rescue
    error -> {url, ["request/render error: #{Exception.message(error)}"]}
  end

  defp check(body) do
    reasons =
      []
      |> require_canonical(body)
      |> require_title_and_description(body)
      |> require_json_ld(body)

    if reasons == [], do: :ok, else: {:error, reasons}
  end

  defp require_canonical(reasons, body) do
    if body =~ ~r/rel="canonical"/, do: reasons, else: ["missing canonical link" | reasons]
  end

  defp require_title_and_description(reasons, body) do
    reasons =
      if body =~ ~r/<title[^>]*>[^<]+<\/title>/,
        do: reasons,
        else: ["missing page title" | reasons]

    if body =~ ~r/<meta[^>]+name="description"[^>]+content="[^"]+"/,
      do: reasons,
      else: ["missing meta description" | reasons]
  end

  defp require_json_ld(reasons, body) do
    scripts =
      Regex.scan(~r/<script[^>]*type="application\/ld\+json"[^>]*>([\s\S]*?)<\/script>/, body,
        capture: :all_but_first
      )

    if scripts == [] do
      ["missing JSON-LD" | reasons]
    else
      scripts
      |> Enum.flat_map(fn [json] ->
        case Jason.decode(json) do
          {:ok, decoded} -> validate_objects(decoded)
          {:error, _} -> ["invalid JSON-LD"]
        end
      end)
      |> Kernel.++(reasons)
    end
  end

  defp validate_objects(value) when is_list(value), do: Enum.flat_map(value, &validate_objects/1)

  defp validate_objects(%{"@type" => type} = object) when is_binary(type) do
    required = Map.get(@required, type, [])

    missing =
      Enum.flat_map(required, fn key ->
        if Map.has_key?(object, key), do: [], else: ["#{type} missing #{key}"]
      end)

    nested =
      object
      |> Map.values()
      |> Enum.flat_map(fn
        %{"@type" => _} = child -> validate_objects(child)
        list when is_list(list) -> Enum.flat_map(list, &validate_objects/1)
        _ -> []
      end)

    missing ++ nested
  end

  defp validate_objects(map) when is_map(map) do
    map |> Map.values() |> Enum.flat_map(&validate_objects/1)
  end

  defp validate_objects(_), do: []
end
