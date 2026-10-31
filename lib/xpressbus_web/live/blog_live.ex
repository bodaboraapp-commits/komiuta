defmodule XpressbusWeb.BlogLive do
  @moduledoc """
  Public travel blog: index at `/blog` and articles at `/blog/:slug`.

  Articles are structured launch guides with full metadata, BlogPosting +
  FAQPage schema and internal links to route and city landing pages.
  """

  use XpressbusWeb, :live_view

  import XpressbusWeb.BrandComponents

  alias XpressbusWeb.Blog
  alias XpressbusWeb.SEO

  @impl true
  def mount(_params, session, socket) do
    {:ok,
     socket
     |> assign(:step, :blog)
     |> assign(:footer_tab, "about")
     |> assign(:current_user, session["user_id"])
     |> assign(:posts, Blog.all())
     |> assign(:post, nil)
     |> assign(:related_posts, [])
     |> assign(:page_title, "Komiuta Travel Blog")
     |> assign(
       :page_description,
       "Practical bus travel guides for Kenya and East Africa: route fares, terminals, M-PESA payment tips, journey times and booking advice from Komiuta."
     )
     |> assign(:page_canonical, SEO.base_url() <> "/blog")
     |> assign(:page_robots, "index,follow")
     |> assign(:page_json_ld, blog_index_json_ld())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case socket.assigns.live_action do
      :show ->
        case Blog.get(Map.get(params, "slug")) do
          nil ->
            {:noreply, push_navigate(socket, to: "/blog")}

          post ->
            {:noreply,
             socket
             |> assign(:post, post)
             |> assign(:related_posts, Blog.related(post.slug))
             |> assign(:page_title, post.title)
             |> assign(:page_description, post.description)
             |> assign(:page_canonical, SEO.base_url() <> "/blog/" <> post.slug)
             |> assign(:page_json_ld, article_json_ld(post))}
        end

      _index ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("change_footer_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :footer_tab, tab)}
  end

  defp blog_index_json_ld do
    [
      SEO.organization(),
      %{
        "@context" => "https://schema.org",
        "@type" => "Blog",
        "name" => "Komiuta Travel Blog",
        "url" => SEO.base_url() <> "/blog",
        "description" =>
          "Bus travel guides for Kenya and East Africa: fares, terminals, payment and booking advice.",
        "publisher" => %{
          "@type" => "Organization",
          "name" => "Komiuta",
          "url" => SEO.base_url()
        }
      },
      SEO.breadcrumb([
        {"Home", SEO.base_url() <> "/"},
        {"Blog", SEO.base_url() <> "/blog"}
      ])
    ]
  end

  defp article_json_ld(post) do
    url = SEO.base_url() <> "/blog/" <> post.slug

    [
      SEO.organization(),
      %{
        "@context" => "https://schema.org",
        "@type" => "BlogPosting",
        "headline" => post.title,
        "description" => post.description,
        "datePublished" => Date.to_iso8601(post.date),
        "dateModified" => Date.to_iso8601(post.updated),
        "mainEntityOfPage" => %{"@type" => "WebPage", "@id" => url},
        "url" => url,
        "image" => SEO.base_url() <> "/images/hero_bg-1024.avif",
        "author" => %{
          "@type" => "Organization",
          "name" => "Komiuta",
          "url" => SEO.base_url()
        },
        "publisher" => %{
          "@type" => "Organization",
          "name" => "Komiuta",
          "url" => SEO.base_url(),
          "logo" => %{
            "@type" => "ImageObject",
            "url" => SEO.base_url() <> "/images/logo_brand.png"
          }
        }
      },
      SEO.faq_page(post.faqs),
      SEO.breadcrumb([
        {"Home", SEO.base_url() <> "/"},
        {"Blog", SEO.base_url() <> "/blog"},
        {post.title, url}
      ])
    ]
  end
end
