// OTP autofill for every KOMIUTA PWA surface.
//
//  * SMS: uses the WebOTP API on Android/Chrome when the SMS is origin-bound.
//  * SMS/browser autofill: `autocomplete="one-time-code"` already lets iOS and
//    Android offer the code above the keyboard.
//  * Email: OTP emails link to `#code=123456`; the link is opened in the browser
//    and this module fills the six-digit field. Clipboard paste is supported too.
//
// The hook is intentionally standalone (not a LiveView hook) so it also works on
// controller-rendered pages such as /user/verify and /agent/verify.

const OTP_SELECTOR = 'input[autocomplete="one-time-code"], input[data-otp-autofill]'
const CODE_RE = /\b(\d{6})\b/

function extractCode(value) {
  const match = String(value || "").match(CODE_RE)
  return match ? match[1] : null
}

function isVisible(element) {
  return Boolean(element && element.getClientRects().length)
}

function visibleOtpInput() {
  return [...document.querySelectorAll(OTP_SELECTOR)].find(isVisible)
}

function fillOtp(input, code) {
  if (!input || !isVisible(input) || input.value === code) return false

  // Use the native setter so frameworks (including LiveView) see the change.
  const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value")?.set
  if (setter) setter.call(input, code)
  else input.value = code

  input.dispatchEvent(new Event("input", {bubbles: true}))
  input.dispatchEvent(new Event("change", {bubbles: true}))
  input.focus()
  return true
}

function codeFromHash() {
  const hash = window.location.hash.replace(/^#/, "")
  if (!hash) return null

  const params = new URLSearchParams(hash)
  return extractCode(params.get("code") || params.get("otp") || hash)
}

function clearCodeFromHash() {
  history.replaceState(null, "", window.location.pathname + window.location.search)
}

function fillFromHash() {
  const code = codeFromHash()
  if (!code) return

  const attempt = (tries = 0) => {
    const input = visibleOtpInput()
    if (input) {
      fillOtp(input, code)
      clearCodeFromHash()
    } else if (tries < 10) {
      window.setTimeout(() => attempt(tries + 1), 100)
    }
  }

  attempt()
}

function bindPaste(input) {
  if (input.dataset.otpPasteBound) return
  input.dataset.otpPasteBound = "true"

  input.addEventListener("paste", event => {
    const pasted = event.clipboardData?.getData("text") || ""
    const code = extractCode(pasted)
    if (!code) return
    event.preventDefault()
    fillOtp(input, code)
  })
}

async function tryClipboard(input) {
  if (!navigator.clipboard?.readText || !isVisible(input)) return

  try {
    const code = extractCode(await navigator.clipboard.readText())
    if (code && document.activeElement === input) fillOtp(input, code)
  } catch {
    // Permission denied, unsupported, or clipboard empty: normal paste still works.
  }
}

let smsAbortController = null
let smsListenerStarted = false
let clipboardAttempted = new WeakSet()

function startSmsAutofill() {
  if (smsListenerStarted || !("OTPCredential" in window) || !visibleOtpInput()) return
  smsListenerStarted = true

  if (smsAbortController) smsAbortController.abort()
  smsAbortController = new AbortController()

  const timer = window.setTimeout(() => smsAbortController.abort(), 5 * 60 * 1000)

  navigator.credentials
    .get({
      otp: {transport: ["sms"]},
      signal: smsAbortController.signal,
    })
    .then(credential => {
      const code = extractCode(credential?.code)
      const input = visibleOtpInput()
      if (code && input) fillOtp(input, code)
    })
    .catch(() => {
      // No SMS arrived, permission denied, or unsupported: fail silently.
    })
    .finally(() => window.clearTimeout(timer))
}

export function initOtpAutofill() {
  // Refresh OTP inputs whenever LiveView navigates or renders a new panel.
  document
    .querySelectorAll(OTP_SELECTOR)
    .forEach(input => {
      bindPaste(input)
      if (!clipboardAttempted.has(input)) {
        clipboardAttempted.add(input)
        input.addEventListener("click", () => tryClipboard(input), {passive: true})
      }
    })

  fillFromHash()
  startSmsAutofill()
}

document.addEventListener("DOMContentLoaded", initOtpAutofill)
document.addEventListener("phx:page-loading-stop", initOtpAutofill)
document.addEventListener("focusin", event => {
  const input = event.target
  if (!input?.matches?.(OTP_SELECTOR)) return

  bindPaste(input)
  startSmsAutofill()
})
document.addEventListener("input", event => {
  if (!event.target.matches?.(OTP_SELECTOR)) return
  const input = event.target
  if (input.value.length === 6) input.dispatchEvent(new Event("change", {bubbles: true}))
})
