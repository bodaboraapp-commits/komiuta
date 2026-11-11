// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/xpressbus"
import topbar from "../vendor/topbar"
import {initAnalytics} from "./analytics"
import {initOtpAutofill} from "./otp_autofill"

// --- Legacy Agent PWA launch compatibility ---------------------------------
// Older Agent PWA installs were installed from www.komiuta.com with
// /agent as their start_url. A server-side redirect to agent.komiuta.com
// breaks those installs (a cross-origin redirect during launch opens the
// browser instead of the standalone app). Serve /agent on the website host
// for installed apps, and only bounce regular browser visits to the Agent
// subdomain origin.
const agentPwaPath = /^\/agent(\/|$)/.test(window.location.pathname)
const isWebsiteHost = /^(www\.)?komiuta\.com$/i.test(window.location.hostname)
const isStandaloneDisplay =
  window.matchMedia("(display-mode: standalone)").matches ||
  window.navigator.standalone === true

if (isWebsiteHost && agentPwaPath && !isStandaloneDisplay) {
  window.location.replace(
    `https://agent.komiuta.com${window.location.pathname}${window.location.search}${window.location.hash}`
  )
}

document.addEventListener("click", event => {
  const control = event.target.closest("[data-carousel-prev], [data-carousel-next]")
  if (!control) return

  const carousel = control.closest(".relative").querySelector(".offer-carousel")
  const amount = carousel.clientWidth * 0.85
  carousel.scrollBy({left: control.hasAttribute("data-carousel-next") ? amount : -amount, behavior: "smooth"})
})

// Warn before abandoning a generated AI itinerary with unsaved changes.
// This covers reloads/closing the tab and in-app links; LiveView buttons such
// as "Start over" carry their own data-confirm copy.
const UnsavedChanges = {
  mounted() {
    this.onBeforeUnload = event => {
      if (!this.isDirty()) return
      event.preventDefault()
      event.returnValue = ""
    }

    this.onLinkClick = event => {
      if (!this.isDirty()) return
      const link = event.target.closest("a[href]")
      if (!link || link.target === "_blank" || link.hasAttribute("download")) return
      if (!window.confirm("You have unsaved changes. Leave this itinerary anyway?")) {
        event.preventDefault()
        event.stopPropagation()
      }
    }

    window.addEventListener("beforeunload", this.onBeforeUnload)
    document.addEventListener("click", this.onLinkClick, true)
  },
  updated() {
    if (!this.isDirty()) return
    // Keep the permission state consistent when LiveView updates dirty attrs.
    this.el.dataset.unsaved = "true"
  },
  destroyed() {
    window.removeEventListener("beforeunload", this.onBeforeUnload)
    document.removeEventListener("click", this.onLinkClick, true)
  },
  isDirty() {
    return this.el.dataset.dirty === "true"
  },
}

// Auto-dismiss success/info toasts so confirmations never block the page.
const FlashAutoDismiss = {
  mounted() {
    if (this.el.dataset.flashKind === "error") return
    this.timer = window.setTimeout(() => this.el.click(), 6000)
  },
  destroyed() {
    if (this.timer) window.clearTimeout(this.timer)
  },
}

// --- Dialog focus management -------------------------------------------------
// Applies to every current and future role="dialog"/role="alertdialog": moves
// focus inside, traps Tab, closes on Escape and restores the previous focus.
let activeDialog = null
let dialogPreviousFocus = null

const dialogFocusableSelector = [
  "a[href]",
  "button:not([disabled])",
  "input:not([disabled]):not([type='hidden'])",
  "select:not([disabled])",
  "textarea:not([disabled])",
  "[contenteditable='true']",
  "[tabindex]:not([tabindex='-1'])",
].join(",")

function isVisibleDialog(dialog) {
  if (!dialog || dialog.inert) return false
  if (dialog.getAttribute("aria-hidden") === "true") return false
  return dialog.getClientRects().length > 0 && getComputedStyle(dialog).visibility !== "hidden"
}

function focusableIn(dialog) {
  return Array.from(dialog.querySelectorAll(dialogFocusableSelector)).filter(element => {
    if (element.inert || element.getAttribute("aria-hidden") === "true") return false
    return element.getClientRects().length > 0 && getComputedStyle(element).visibility !== "hidden"
  })
}

function focusFirstIn(dialog) {
  if (!dialog) return

  const preferred =
    dialog.querySelector("[autofocus]") ||
    Array.from(dialog.querySelectorAll("input:not([type='hidden']):not([disabled]), textarea:not([disabled]), select:not([disabled])")).find(el => isVisibleDialog(el)) ||
    focusableIn(dialog)[0]

  if (preferred) {
    preferred.focus({preventScroll: true})
  } else {
    dialog.setAttribute("tabindex", "-1")
    dialog.focus({preventScroll: true})
  }
}

function closeDialog(dialog) {
  const close =
    dialog.querySelector("[data-dialog-close]") ||
    dialog.querySelector("[aria-label*='close' i]") ||
    dialog.querySelector("[id$='-close']") ||
    Array.from(dialog.querySelectorAll("button")).find(button => /close|cancel|dismiss/i.test(button.getAttribute("phx-click") || button.textContent || ""))

  if (close) {
    close.click()
    return true
  }

  return false
}

function syncActiveDialog() {
  const dialogs = Array.from(document.querySelectorAll("[role='dialog'], [role='alertdialog']")).filter(isVisibleDialog)
  const next = dialogs[dialogs.length - 1] || null

  if (next === activeDialog) return

  if (next) {
    if (!activeDialog) dialogPreviousFocus = document.activeElement
    activeDialog = next
    window.requestAnimationFrame(() => focusFirstIn(activeDialog))
  } else {
    activeDialog = null

    if (dialogPreviousFocus && document.contains(dialogPreviousFocus)) {
      window.requestAnimationFrame(() => dialogPreviousFocus.focus({preventScroll: true}))
    }

    dialogPreviousFocus = null
  }
}

function initDialogFocusManagement() {
  if (window.__komiutaDialogFocus) return
  window.__komiutaDialogFocus = true

  document.addEventListener("keydown", event => {
    if (!activeDialog) return

    if (event.key === "Escape") {
      if (closeDialog(activeDialog)) {
        event.preventDefault()
        event.stopPropagation()
      }
      return
    }

    if (event.key !== "Tab") return

    const focusable = focusableIn(activeDialog)
    if (focusable.length === 0) {
      event.preventDefault()
      activeDialog.focus({preventScroll: true})
      return
    }

    const first = focusable[0]
    const last = focusable[focusable.length - 1]

    if (event.shiftKey && (document.activeElement === first || !activeDialog.contains(document.activeElement))) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && (document.activeElement === last || !activeDialog.contains(document.activeElement))) {
      event.preventDefault()
      first.focus()
    }
  })

  document.addEventListener("focusin", event => {
    if (activeDialog && !activeDialog.contains(event.target)) {
      focusFirstIn(activeDialog)
    }
  })

  const observer = new MutationObserver(() => window.requestAnimationFrame(syncActiveDialog))
  observer.observe(document.body, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ["inert", "aria-hidden", "class", "style"],
  })

  syncActiveDialog()
}

// --- Tablist keyboard navigation --------------------------------------------
function initTabArrowNavigation() {
  if (window.__komiutaTabArrowNavigation) return
  window.__komiutaTabArrowNavigation = true

  document.addEventListener("keydown", event => {
    if (event.altKey || event.ctrlKey || event.metaKey) return
    if (!["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "Home", "End"].includes(event.key)) return

    const tab = event.target.closest("[role='tab']")
    if (!tab || tab.disabled) return

    const tablist = tab.closest("[role='tablist']")
    if (!tablist) return

    const tabs = Array.from(tablist.querySelectorAll("[role='tab']")).filter(item => !item.disabled)
    if (tabs.length === 0) return

    const current = Math.max(0, tabs.indexOf(tab))
    let next = current

    if (event.key === "Home") next = 0
    if (event.key === "End") next = tabs.length - 1
    if (event.key === "ArrowRight" || event.key === "ArrowDown") next = (current + 1) % tabs.length
    if (event.key === "ArrowLeft" || event.key === "ArrowUp") next = (current - 1 + tabs.length) % tabs.length

    tabs.forEach((item, index) => {
      item.tabIndex = index === next ? 0 : -1
    })

    event.preventDefault()
    tabs[next].focus()
    tabs[next].click()
  })
}

initDialogFocusManagement()
initTabArrowNavigation()

// Prevent double-submitting non-LiveView forms (e.g. account creation).
document.addEventListener("submit", event => {
  const form = event.target
  if (!(form instanceof HTMLFormElement) || !form.matches("[data-submit-once]")) return
  const button = form.querySelector("button[type='submit']")
  if (!button || button.disabled) return
  button.disabled = true
  button.dataset.originalLabel = button.textContent
  button.textContent = button.dataset.loadingLabel || "Working…"
})

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, UnsavedChanges, FlashAutoDismiss},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Trip share buttons in the Chyllz account tab: use the native share sheet
// where available and fall back to copying the itinerary URL.
window.addEventListener("phx:share_trip", async ({detail}) => {
  if (!detail || !detail.url) return

  let url = detail.url
  try {
    url = new URL(detail.url, window.location.origin).toString()
  } catch (_error) {
    return
  }

  try {
    if (navigator.share) {
      await navigator.share({title: detail.title || document.title, url})
    } else if (navigator.clipboard) {
      await navigator.clipboard.writeText(url)
    }
  } catch (_error) {
    // A dismissed share sheet is not an error worth surfacing.
  }
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// Campaign attribution + funnel events (UTM aware; GA4 optional).
initAnalytics()

// SMS WebOTP + email-code autofill for every OTP input in both PWAs.
initOtpAutofill()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// --- PWA: install prompt ---------------------------------------------------
// The browser fires `beforeinstallprompt` when the app is installable. Store
// it so the in-app "Install app" buttons can trigger it later.
window.__komiutaInstallPrompt = null

window.addEventListener('beforeinstallprompt', event => {
  event.preventDefault()
  window.__komiutaInstallPrompt = event
  window.dispatchEvent(new CustomEvent('komiuta:pwa-installable'))
})

window.addEventListener('appinstalled', () => {
  window.__komiutaInstallPrompt = null
  window.dispatchEvent(new CustomEvent('komiuta:pwa-installed'))
})

// --- PWA: service worker + update handling ---------------------------------
if ('serviceWorker' in navigator) {
  const hadController = !!navigator.serviceWorker.controller
  let refreshing = false

  navigator.serviceWorker.addEventListener('controllerchange', () => {
    // Reload once when a new service worker takes over, but not on first install.
    if (!hadController || refreshing) return
    refreshing = true
    window.location.reload()
  })

  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').catch(() => {
      // Offline support is a progressive enhancement; ignore failures silently.
    })
  })
}

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

