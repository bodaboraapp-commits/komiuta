// First-party capture of campaign attribution plus conversion events.
//
// UTM/gclid/fbclid values from the first landing URL are kept in
// sessionStorage and attached to every tracked event, so a booking started
// from an organic SEO page can be attributed even after LiveView navigation.
// Events are pushed to window.dataLayer (for GTM/GA4) and dispatched as a
// `komiuta:analytics` DOM event for any other listener.

const UTM_KEY = "komiuta:utm:v1"
const UTM_FIELDS = [
  "utm_source",
  "utm_medium",
  "utm_campaign",
  "utm_term",
  "utm_content",
  "gclid",
  "fbclid",
]

function captureAttribution() {
  try {
    const params = new URLSearchParams(window.location.search)
    const found = {}
    let hasAny = false

    for (const field of UTM_FIELDS) {
      const value = params.get(field)
      if (value) {
        found[field] = value.slice(0, 200)
        hasAny = true
      }
    }

    if (hasAny) {
      sessionStorage.setItem(UTM_KEY, JSON.stringify(found))
      return found
    }

    const stored = sessionStorage.getItem(UTM_KEY)
    return stored ? JSON.parse(stored) : {}
  } catch (_e) {
    return {}
  }
}

export function attribution() {
  try {
    const stored = sessionStorage.getItem(UTM_KEY)
    return stored ? JSON.parse(stored) : {}
  } catch (_e) {
    return {}
  }
}

export function track(event, props = {}) {
  if (!event) return

  const payload = {...attribution(), ...props, page_path: window.location.pathname}

  window.dataLayer = window.dataLayer || []
  window.dataLayer.push({event, ...payload})

  if (typeof window.gtag === "function") {
    window.gtag("event", event, payload)
  }

  document.dispatchEvent(new CustomEvent("komiuta:analytics", {detail: {event, ...payload}}))
}

function loadGtag() {
  const meta = document.querySelector('meta[name="ga-measurement-id"]')
  const measurementId = meta && meta.getAttribute("content")
  if (!measurementId || window.gtag) return

  const script = document.createElement("script")
  script.async = true
  script.src = `https://www.googletagmanager.com/gtag/js?id=${encodeURIComponent(measurementId)}`
  document.head.appendChild(script)

  window.dataLayer = window.dataLayer || []
  window.gtag = function () {
    window.dataLayer.push(arguments)
  }
  window.gtag("js", new Date())
  window.gtag("config", measurementId, {send_page_view: false})
}

export function initAnalytics() {
  captureAttribution()
  loadGtag()

  track("page_view", {page_title: document.title})

  if (window.location.pathname.startsWith("/tickets")) {
    track("ticket_view")
  }

  document.addEventListener(
    "click",
    (event) => {
      const control = event.target.closest("[data-track]")
      if (!control || control.disabled) return

      track(control.dataset.track, {
        label: control.dataset.trackLabel || undefined,
        value: control.dataset.trackValue || undefined,
      })
    },
    true
  )
}
