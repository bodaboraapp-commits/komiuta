defmodule XpressbusWeb.ChyllzAccountArt do
  @moduledoc """
  Inline SVG artwork for the Chyllz account landing page.

  The page is deliberately dependency-free: icons are inline strokes, the trip
  cards get a small scenic illustration instead of a stock photo, and the
  weather glyphs are drawn locally. That keeps the page fast (no icon font or
  image round-trips) and lets every colour follow the Komiuta orange palette.
  """

  use Phoenix.Component

  @doc """
  A stroked UI icon. Supported names: `:compass`, `:ticket`, `:chevron_right`,
  `:arrow_right`, `:pin`, `:calendar`, `:clock`, `:wallet`, `:seat`, `:search`,
  `:refresh`, `:route`, `:bag`, `:star`, `:sparkles`, `:plane`, `:map`, `:check`,
  `:list`, `:eye`, `:share`, `:users`, `:sliders`, `:user`, `:heart`, `:paw`,
  `:money`, `:gem`, `:rocket`, `:bot`.
  """
  attr :name, :atom, required: true
  attr :class, :string, default: "h-5 w-5"

  def ui_icon(assigns) do
    ~H"""
    <svg
      class={@class}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="1.8"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <%= case @name do %>
        <% :compass -> %>
          <circle cx="12" cy="12" r="9" /> <path d="m15.6 8.4-2.1 5.1-5.1 2.1 2.1-5.1z" />
        <% :ticket -> %>
          <path d="M4 8a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v2a2 2 0 0 0 0 4v2a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-2a2 2 0 0 0 0-4z" />
          <path d="M14 6v12" stroke-dasharray="2 2.5" />
        <% :chevron_right -> %>
          <path d="m9 6 6 6-6 6" />
        <% :arrow_right -> %>
          <path d="M4 12h15" /> <path d="m13 6 6 6-6 6" />
        <% :pin -> %>
          <path d="M12 21s7-6.1 7-11a7 7 0 1 0-14 0c0 4.9 7 11 7 11z" />
          <circle cx="12" cy="10" r="2.6" />
        <% :calendar -> %>
          <rect x="3.5" y="5.5" width="17" height="15" rx="3" />
          <path d="M8 3.5v4M16 3.5v4M3.5 10.5h17" />
        <% :clock -> %>
          <circle cx="12" cy="12" r="8.5" /> <path d="M12 7.5V12l3 2" />
        <% :wallet -> %>
          <rect x="3" y="6" width="18" height="13" rx="3" /> <path d="M3 10h18" />
          <circle cx="16.5" cy="14.5" r="1.2" fill="currentColor" stroke="none" />
        <% :seat -> %>
          <path d="M6 4v9.5A2.5 2.5 0 0 0 8.5 16H17" /> <path d="M17 8v6a2 2 0 0 1-2 2H8" />
          <path d="M6 17v3M18 17v3" />
        <% :search -> %>
          <circle cx="11" cy="11" r="6.5" /> <path d="m16 16 4 4" />
        <% :drop -> %>
          <path d="M12 3.5c3.2 4 5 6.6 5 9a5 5 0 0 1-10 0c0-2.4 1.8-5 5-9z" />
        <% :wind -> %>
          <path d="M3 8h10a3 3 0 1 0-3-3" /> <path d="M3 12h14a3 3 0 1 1-3 3" /> <path d="M3 16h6" />
        <% :refresh -> %>
          <path d="M20 11a8 8 0 1 0-2.3 6.2" /> <path d="M20 4.5V11h-6" />
        <% :route -> %>
          <circle cx="6" cy="18" r="2.5" /> <circle cx="18" cy="6" r="2.5" />
          <path d="M8.5 18h4a3 3 0 0 0 3-3V8.5" stroke-dasharray="3 3" />
        <% :bag -> %>
          <rect x="4" y="7" width="16" height="13" rx="3" />
          <path d="M9 7V5.5A1.5 1.5 0 0 1 10.5 4h3A1.5 1.5 0 0 1 15 5.5V7" /> <path d="M4 12h16" />
        <% :star -> %>
          <path d="m12 3.5 2.6 5.3 5.9.9-4.2 4.1 1 5.8-5.3-2.8-5.3 2.8 1-5.8-4.2-4.1 5.9-.9z" />
        <% :sparkles -> %>
          <path d="M12 4v5M9.5 6.5h5" /> <path d="M18 13v4M16 15h4" /> <path d="M6 14v3M4.5 15.5h3" />
        <% :plane -> %>
          <path d="m3 13 18-7-6 15-3.5-6z" /> <path d="M13 12 21 6" />
        <% :map -> %>
          <path d="m3 6.5 6-2.5 6 2.5 6-2.5v13l-6 2.5-6-2.5-6 2.5z" /> <path d="M9 4v13M15 7v13" />
        <% :check -> %>
          <path d="m5 12.5 4.5 4.5L19 7.5" />
        <% :list -> %>
          <path d="M4 7h9M4 12h13M4 17h7" /> <circle cx="16.5" cy="7" r="1.6" />
          <circle cx="20" cy="12" r="1.6" /> <circle cx="14.5" cy="17" r="1.6" />
        <% :eye -> %>
          <path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z" />
          <circle cx="12" cy="12" r="3" />
        <% :share -> %>
          <circle cx="6" cy="12" r="2.5" /> <circle cx="18" cy="6" r="2.5" />
          <circle cx="18" cy="18" r="2.5" /> <path d="m8.2 10.8 7.6-3.6M8.2 13.2l7.6 3.6" />
        <% :users -> %>
          <circle cx="9" cy="8" r="3.5" /> <path d="M3.5 19.5c.7-3.3 2.9-5 5.5-5s4.8 1.7 5.5 5" />
          <path d="M15.5 5.4a3.4 3.4 0 0 1 0 6.2M17 14.8c2 .6 3.2 2.1 3.6 4.4" />
        <% :user -> %>
          <circle cx="12" cy="8" r="3.6" /> <path d="M4.5 20c.9-3.8 3.6-5.8 7.5-5.8s6.6 2 7.5 5.8" />
        <% :heart -> %>
          <path d="M12 20.5S3.5 15 3.5 8.9A4.6 4.6 0 0 1 12 6a4.6 4.6 0 0 1 8.5 2.9c0 6.1-8.5 11.6-8.5 11.6z" />
        <% :paw -> %>
          <ellipse cx="7" cy="9" rx="2" ry="2.6" /> <ellipse cx="17" cy="9" rx="2" ry="2.6" />
          <ellipse cx="4.5" cy="14" rx="1.8" ry="2.1" />
          <ellipse cx="19.5" cy="14" rx="1.8" ry="2.1" />
          <path d="M12 13.2c3.1 0 5.5 2.9 5.5 5.1 0 1.7-1.3 2.7-2.9 2.4-1.7-.3-3.4-.3-5.1 0-1.7.3-3-.7-3-2.4 0-2.2 2.4-5.1 5.5-5.1z" />
        <% :money -> %>
          <path d="M9 6.5h6l3 4.2c.5.7.3 1.6-.4 2.1L12 17l-5.6-4.2c-.7-.5-.9-1.4-.4-2.1z" />
          <path d="M12 9v5M10.4 10.3h2.4a1 1 0 0 1 0 2h-1.6a1 1 0 0 0 0 2h2.4" />
        <% :gem -> %>
          <path d="M6 4h12l3 5-9 11L3 9z" />
          <path d="M3 9h18M9 4l-1.5 5L12 20l4.5-11L15 4M9 9l3 11 3-11" />
        <% :rocket -> %>
          <path d="M13.5 5.5c3-3 6.5-2.8 6.5-2.8s.2 3.5-2.8 6.5l-3.7 3.7-4.2-1.1-1.2-4.2z" />
          <path d="M9 13 6 16M11 17l-1 3M7 15H3.5L6 12.5M9 9 6.5 6.5 8 3l3 2.5" />
        <% :sliders -> %>
          <path d="M4 7h16M4 12h16M4 17h16" /> <circle cx="9" cy="7" r="2" fill="white" />
          <circle cx="15" cy="12" r="2" fill="white" /> <circle cx="7" cy="17" r="2" fill="white" />
        <% :bot -> %>
          <rect x="5" y="8" width="14" height="10.5" rx="3" />
          <path d="M12 4v4M9 18.5v2M15 18.5v2M3.5 10v5M20.5 10v5" />
          <circle cx="12" cy="3.4" r="1" fill="currentColor" stroke="none" />
          <circle cx="9.5" cy="12.5" r="1.1" fill="currentColor" stroke="none" />
          <circle cx="14.5" cy="12.5" r="1.1" fill="currentColor" stroke="none" />
          <path d="M9.5 15.5h5" />
        <% :edit -> %>
          <path d="M4 20h4l10.5-10.5a2.8 2.8 0 0 0-4-4L4 16v4z" />
          <path d="m13.5 6.5 4 4" />
        <% :content_copy -> %>
          <rect x="8" y="8" width="12" height="12" rx="2.5" />
          <path d="M16 8V5.5A1.5 1.5 0 0 0 14.5 4H5.5A1.5 1.5 0 0 0 4 5.5v9A1.5 1.5 0 0 0 5.5 16H8" />
        <% :delete -> %>
          <path d="M4 7h16M9.5 7V4.5h5V7M6.5 7l1 13h9l1-13" />
          <path d="M10 11v5M14 11v5" />
        <% _other -> %>
          <circle cx="12" cy="12" r="8.5" />
      <% end %>
    </svg>
    """
  end

  @doc """
  A weather glyph for the forecast card. Supported icons: `:clear`,
  `:partly_cloudy`, `:cloud`, `:fog`, `:rain`, `:snow`, `:storm`.
  """
  attr :icon, :atom, required: true
  attr :class, :string, default: "h-9 w-9"

  def weather_glyph(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 48 48" fill="none" aria-hidden="true">
      <%= case @icon do %>
        <% :clear -> %>
          <circle cx="24" cy="24" r="8.5" fill="#FFB020" />
          <g stroke="#FFB020" stroke-width="2.4" stroke-linecap="round">
            <path d="M24 6v5M24 37v5M6 24h5M37 24h5M11.3 11.3l3.5 3.5M33.2 33.2l3.5 3.5M36.7 11.3l-3.5 3.5M14.8 33.2l-3.5 3.5" />
          </g>
        <% :partly_cloudy -> %>
          <circle cx="31" cy="17" r="7" fill="#FFB020" />
          <path
            d="M31 5.5V8M43 17h-2.5M39.5 8.5l-1.8 1.8M39.5 25.5l-1.8-1.8"
            stroke="#FFB020"
            stroke-width="2.2"
            stroke-linecap="round"
          />
          <path
            d="M15 36a6.5 6.5 0 0 1-.6-13 8.5 8.5 0 0 1 16.4 1.6A5.7 5.7 0 0 1 30.5 36z"
            fill="#CBD5E1"
          />
        <% :cloud -> %>
          <path
            d="M15 36a6.5 6.5 0 0 1-.6-13 8.5 8.5 0 0 1 16.4 1.6A5.7 5.7 0 0 1 30.5 36z"
            fill="#CBD5E1"
          />
        <% :fog -> %>
          <path
            d="M15 30a6.5 6.5 0 0 1-.6-13 8.5 8.5 0 0 1 16.4 1.6A5.7 5.7 0 0 1 30.5 30z"
            fill="#CBD5E1"
          />
          <path d="M12 35.5h19M16 40h19" stroke="#94A3B8" stroke-width="2.4" stroke-linecap="round" />
        <% :rain -> %>
          <path
            d="M15 29a6.5 6.5 0 0 1-.6-13 8.5 8.5 0 0 1 16.4 1.6A5.7 5.7 0 0 1 30.5 29z"
            fill="#CBD5E1"
          />
          <g stroke="#38BDF8" stroke-width="2.6" stroke-linecap="round">
            <path d="M16 34.5l-1.6 5M24 34.5l-1.6 5M32 34.5l-1.6 5" />
          </g>
        <% :snow -> %>
          <path
            d="M15 29a6.5 6.5 0 0 1-.6-13 8.5 8.5 0 0 1 16.4 1.6A5.7 5.7 0 0 1 30.5 29z"
            fill="#CBD5E1"
          />
          <g fill="#7DD3FC">
            <circle cx="16" cy="36" r="2" /> <circle cx="24" cy="39.5" r="2" />
            <circle cx="32" cy="36" r="2" />
          </g>
        <% :storm -> %>
          <path
            d="M15 28a6.5 6.5 0 0 1-.6-13 8.5 8.5 0 0 1 16.4 1.6A5.7 5.7 0 0 1 30.5 28z"
            fill="#94A3B8"
          /> <path d="M25 30l-5 9h5l-2 7 8-10h-5l2-6z" fill="#FFB020" />
        <% _other -> %>
          <path
            d="M15 34a6.5 6.5 0 0 1-.6-13 8.5 8.5 0 0 1 16.4 1.6A5.7 5.7 0 0 1 30.5 34z"
            fill="#CBD5E1"
          />
      <% end %>
    </svg>
    """
  end

  @doc """
  A warm, scenic illustration for a trip card. Variants: `:mountains`, `:coast`
  and `:savanna`. The art fills its container (`slice`).

  `tag` must be unique per rendered card (the trip id is used): SVG gradient
  ids have to be unique in the document.
  """
  attr :variant, :atom, required: true
  attr :tag, :string, default: ""
  attr :class, :string, default: "h-full w-full"

  def trip_art(assigns) do
    assigns = assign(assigns, :key, sanitize_tag(assigns.tag))

    ~H"""
    <svg
      class={@class}
      viewBox="0 0 320 220"
      preserveAspectRatio="xMidYMid slice"
      aria-hidden="true"
    >
      <%= case @variant do %>
        <% :mountains -> %>
          <defs>
            <linearGradient id={"trip-sky-mountains-" <> @key} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stop-color="#FFEEDD" /> <stop offset="1" stop-color="#FFD9B0" />
            </linearGradient>

            <linearGradient id={"trip-lake-mountains-" <> @key} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stop-color="#7DD3FC" /> <stop offset="1" stop-color="#38BDF8" />
            </linearGradient>
          </defs>
          <rect width="320" height="220" fill={"url(#trip-sky-mountains-#{@key})"} />
          <circle cx="250" cy="62" r="34" fill="#FF8A00" opacity="0.16" />
          <circle cx="250" cy="62" r="22" fill="#FF8A00" opacity="0.9" />
          <path d="M-20 152 70 66 122 124 172 62 258 152Z" fill="#475569" opacity="0.45" />
          <path d="M18 176 118 66 178 140 236 84 330 176Z" fill="#334155" />
          <path d="M118 66 142 96 130 100 118 90 106 102 96 98Z" fill="#F8FAFC" opacity="0.95" />
          <path d="M236 84 258 108 244 112 236 102 226 112 216 106Z" fill="#F8FAFC" opacity="0.8" />
          <path
            d="M0 178c58-12 112 14 170 2 58-12 104 8 150-2v42H0Z"
            fill={"url(#trip-lake-mountains-#{@key})"}
          />
          <path
            d="M58 198h38M132 190h48M226 202h38"
            stroke="#E0F2FE"
            stroke-width="3"
            stroke-linecap="round"
            opacity="0.85"
          /> <path d="M40 174l10-18 10 18zM64 178l8-14 8 14zM268 176l9-16 9 16z" fill="#14532D" />
          <path
            d="M196 98q6-7 13 0M216 92q6-7 13 0"
            stroke="#7C2D12"
            stroke-width="2.4"
            fill="none"
            stroke-linecap="round"
          />
        <% :coast -> %>
          <defs>
            <linearGradient id={"trip-sky-coast-" <> @key} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stop-color="#FFE9CE" /> <stop offset="1" stop-color="#FFC9A0" />
            </linearGradient>

            <linearGradient id={"trip-sea-coast-" <> @key} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stop-color="#22D3EE" /> <stop offset="1" stop-color="#0E7490" />
            </linearGradient>
          </defs>
          <rect width="320" height="220" fill={"url(#trip-sky-coast-#{@key})"} />
          <circle cx="252" cy="54" r="30" fill="#FF8A00" opacity="0.16" />
          <circle cx="252" cy="54" r="19" fill="#FF8A00" opacity="0.9" />
          <rect y="124" width="320" height="96" fill={"url(#trip-sea-coast-#{@key})"} />
          <path
            d="M0 132c46-10 90 10 138 0 48-10 96 10 182-2v10c-84 12-134-8-182 2-48 10-92-10-138 0z"
            fill="#E0F2FE"
            opacity="0.55"
          /> <path d="M0 178c52-10 98 8 150 0 52-8 106 12 170 0v42H0Z" fill="#FDE68A" />
          <path
            d="M0 186c52-8 98 6 150 0 52-6 106 8 170 0v6c-64 8-118-6-170 0-52 6-98-8-150 0z"
            fill="#FCD34D"
          />
          <path d="M226 174c-2-30 0-52 6-72" stroke="#7C2D12" stroke-width="7" stroke-linecap="round" />
          <g fill="#15803D">
            <path d="M232 96c-18-16-38-14-46-4 14 2 28 6 46 4z" />
            <path d="M232 96c18-18 40-16 48-4-16 2-30 6-48 4z" />
            <path d="M232 96c-12-20-2-38 12-42-2 16-4 28-12 42z" />
            <path d="M232 96c12-18 4-36-10-42 4 16 4 28 10 42z" />
            <path d="M232 96c6-16 22-26 36-22-12 10-22 16-36 22z" />
          </g>
          <path d="M70 120 88 120 79 102Z" fill="#F8FAFC" />
          <path d="M48 132h84l-10 8H58Z" fill="#F8FAFC" opacity="0.9" />
          <path
            d="M120 92q6-7 13 0M144 84q6-7 13 0"
            stroke="#7C2D12"
            stroke-width="2.2"
            fill="none"
            stroke-linecap="round"
          />
        <% :savanna -> %>
          <defs>
            <linearGradient id={"trip-sky-savanna-" <> @key} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stop-color="#FFEDB8" /> <stop offset="1" stop-color="#FFB86B" />
            </linearGradient>
          </defs>
          <rect width="320" height="220" fill={"url(#trip-sky-savanna-#{@key})"} />
          <circle cx="170" cy="116" r="62" fill="#FF8A00" opacity="0.18" />
          <circle cx="170" cy="116" r="46" fill="#FF8A00" opacity="0.92" />
          <path d="M0 158c62-16 112 10 168 0 56-10 102 10 152-4v66H0Z" fill="#D97706" />
          <path d="M0 186c58-12 108 8 164 0 56-8 100 10 156-4v38H0Z" fill="#B45309" />
          <path d="M64 158c-2-24 0-42 4-58" stroke="#3F2D1A" stroke-width="6" stroke-linecap="round" />
          <path d="M66 100c-20-4-34-12-40-22 16 0 30 6 40 14z" fill="#3F2D1A" />
          <path d="M66 100c20-6 34-14 40-26-16 0-30 8-40 18z" fill="#3F2D1A" />
          <path d="M66 84c-14-2-26-8-32-16 14-2 26 2 34 8z" fill="#3F2D1A" />
          <path d="M226 180c-1-16 0-28 3-40" stroke="#3F2D1A" stroke-width="4" stroke-linecap="round" />
          <path d="M228 142c-12-2-20-8-24-14 10-2 18 2 24 8z" fill="#3F2D1A" />
          <path d="M228 142c12-4 20-10 24-16-10-2-18 2-24 10z" fill="#3F2D1A" />
          <path
            d="M118 196q4-8 8 0M206 202q4-8 8 0M282 194q4-8 8 0"
            stroke="#3F2D1A"
            stroke-width="2.4"
            fill="none"
            stroke-linecap="round"
          />
          <path
            d="M40 64q7-8 15 0M60 56q7-8 15 0"
            stroke="#7C2D12"
            stroke-width="2.2"
            fill="none"
            stroke-linecap="round"
          />
      <% end %>
    </svg>
    """
  end

  # SVG ids may only contain a conservative character set; the tag keeps each
  # rendered card's gradient ids unique.
  defp sanitize_tag(tag) when is_binary(tag) do
    tag
    |> String.replace(~r/[^A-Za-z0-9_-]/, "-")
    |> String.slice(0, 60)
  end

  defp sanitize_tag(_tag), do: "art"
end
