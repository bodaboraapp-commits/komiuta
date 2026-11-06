// Source for the vendored Firebase Phone Auth bundle used on /user/login.
// The generated browser bundle is committed at assets/js/firebase_phone_auth.js
// (so Render does not need npm at build time). Rebuild after editing this file:
//
//   npx --yes esbuild@0.25.4 assets/js/firebase_phone_auth.source.js \
//     --bundle --minify --format=iife --target=es2022 \
//     --outfile=assets/js/firebase_phone_auth.js
import { initializeApp } from "firebase/app"
import { getAuth, RecaptchaVerifier, signInWithPhoneNumber } from "firebase/auth"

const root = document.getElementById("firebase-sms-auth")

if (root) {
  initSmsLogin(root)
}

function initSmsLogin(root) {
  const form = root.querySelector("#firebase-sms-form")
  const phoneInput = root.querySelector("#firebase-phone")
  const sendButton = root.querySelector("#firebase-send-code")
  const codeStep = root.querySelector("#firebase-code-step")
  const codeInput = root.querySelector("#firebase-code")
  const changeNumberButton = root.querySelector("#firebase-change-number")
  const statusEl = root.querySelector("#firebase-status")
  const phoneHint = root.querySelector("#firebase-phone-hint")
  const verifyUrl = root.dataset.verifyUrl || "/user/firebase/verify"
  const successRedirect = root.dataset.redirect || "/dashboard"

  const config = {
    apiKey: root.dataset.apiKey,
    authDomain: root.dataset.authDomain,
    projectId: root.dataset.projectId,
    storageBucket: root.dataset.storageBucket,
    messagingSenderId: root.dataset.messagingSenderId,
    appId: root.dataset.appId,
  }

  if (!config.apiKey || !config.projectId || !config.appId) {
    setStatus("SMS login is not configured.", "error")
    return
  }

  let auth
  let verifier
  let confirmationResult = null
  let otpAbortController = null

  try {
    const app = initializeApp(config, "komiuta-sms")
    auth = getAuth(app)
    auth.languageCode = "en"
    verifier = new RecaptchaVerifier(auth, "firebase-recaptcha", {size: "invisible"})
  } catch (_error) {
    setStatus("SMS login could not start. Please use the email code instead.", "error")
    return
  }

  form.addEventListener("submit", event => {
    event.preventDefault()
    if (confirmationResult) {
      verifyCode()
    } else {
      sendCode()
    }
  })

  phoneInput.addEventListener("input", updatePhoneHint)
  updatePhoneHint()

  changeNumberButton.addEventListener("click", () => {
    stopSmsOtpListener()
    confirmationResult = null
    codeStep.classList.add("hidden")
    sendButton.classList.remove("hidden")
    phoneInput.removeAttribute("readonly")
    codeInput.value = ""
    updatePhoneHint()
    setStatus("")
    phoneInput.focus()
  })

  async function sendCode() {
    const phone = normalizePhone(phoneInput.value)

    if (!/^\+[1-9]\d{7,14}$/.test(phone)) {
      setStatus("Enter a valid phone number, for example 0712 345 678.", "error")
      phoneInput.focus()
      return
    }

    setBusy(true)
    setStatus("Sending your SMS code…")
    listenForSmsOtp(phone)

    try {
      await resetVerifier()
      confirmationResult = await signInWithPhoneNumber(auth, phone, verifier)

      codeStep.classList.remove("hidden")
      sendButton.classList.add("hidden")
      phoneInput.setAttribute("readonly", "readonly")
      setStatus(`Code sent to ${displayPhone(phone)}. Enter the 6-digit code from the SMS.`, "success")
      codeInput.focus()
    } catch (error) {
      stopSmsOtpListener()
      setStatus(friendlyError(error), "error")
      await resetVerifier()
    } finally {
      setBusy(false)
    }
  }

  async function verifyCode() {
    const code = codeInput.value.trim()

    if (!/^\d{6}$/.test(code)) {
      setStatus("Enter the 6-digit code from the SMS.", "error")
      codeInput.focus()
      return
    }

    setBusy(true)
    setStatus("Verifying your code…")

    try {
      const credential = await confirmationResult.confirm(code)
      stopSmsOtpListener()
      const idToken = await credential.user.getIdToken()

      const response = await fetch(verifyUrl, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-csrf-token": csrfToken(),
        },
        body: JSON.stringify({id_token: idToken}),
      })

      const data = await response.json().catch(() => ({}))

      if (!response.ok) {
        throw new Error(data.error || "That code could not be verified.")
      }

      window.location.assign(data.redirect || successRedirect)
    } catch (error) {
      setStatus(friendlyError(error), "error")
      codeInput.focus()
    } finally {
      setBusy(false)
    }
  }

  function updatePhoneHint() {
    if (!phoneHint) return

    const e164 = normalizePhone(phoneInput.value)

    if (/^\+[1-9]\d{7,14}$/.test(e164)) {
      phoneHint.textContent = `Your one-time code will be sent to ${displayPhone(e164)}.`
    } else {
      phoneHint.textContent = "Enter the phone number that should receive your one-time code."
    }
  }

  function displayPhone(e164) {
    const digits = String(e164 || "").replace(/\D/g, "")

    if (digits.startsWith("254") && digits.length === 12) {
      return `+254 ${digits.slice(3, 6)} ${digits.slice(6, 9)} ${digits.slice(9, 12)}`
    }

    return e164
  }

  function listenForSmsOtp(phone) {
    stopSmsOtpListener()

    if (!("OTPCredential" in window) || !navigator.credentials || !navigator.credentials.get) {
      return
    }

    otpAbortController = new AbortController()

    navigator.credentials
      .get({
        otp: {transport: ["sms"]},
        signal: otpAbortController.signal,
      })
      .then(otp => {
        if (!otp || !otp.code) return

        codeInput.value = otp.code
        codeInput.dispatchEvent(new Event("input", {bubbles: true}))
        setStatus(`Code received for ${displayPhone(phone)}. Tap Verify & Sign In.`, "success")
        codeInput.focus()
      })
      .catch(error => {
        // AbortError is normal when the number is changed or the code is already used.
        if (error && error.name !== "AbortError") {
          console.warn("SMS OTP autofill unavailable", error)
        }
      })
  }

  function stopSmsOtpListener() {
    if (otpAbortController) {
      otpAbortController.abort()
      otpAbortController = null
    }
  }

  async function resetVerifier() {
    try {
      if (verifier) verifier.clear()
    } catch (_error) {
      // Ignore reCAPTCHA cleanup errors; a fresh verifier is created below.
    }

    const container = document.getElementById("firebase-recaptcha")
    if (container) container.innerHTML = ""

    verifier = new RecaptchaVerifier(auth, "firebase-recaptcha", {size: "invisible"})
  }

  function setBusy(busy) {
    sendButton.disabled = busy
    if (codeStep) {
      const verifyButton = codeStep.querySelector("#firebase-verify-code")
      if (verifyButton) verifyButton.disabled = busy
    }
  }

  function setStatus(message, type = "") {
    statusEl.textContent = message
    statusEl.classList.remove("text-red-500", "text-emerald-600", "text-slate-500")
    statusEl.classList.add(
      type === "error" ? "text-red-500" : type === "success" ? "text-emerald-600" : "text-slate-500"
    )
  }
}

function normalizePhone(value) {
  const trimmed = String(value || "").trim()
  const digits = trimmed.replace(/\D/g, "")

  if (trimmed.startsWith("+")) return "+" + digits
  if (digits.startsWith("0") && digits.length === 10) return "+254" + digits.slice(1)
  if (digits.startsWith("254") && digits.length === 12) return "+" + digits
  if (digits.length === 9) return "+254" + digits
  return "+" + digits
}

function csrfToken() {
  const meta = document.querySelector("meta[name='csrf-token']")
  return meta ? meta.getAttribute("content") : ""
}

function friendlyError(error) {
  const code = (error && error.code) || ""

  const messages = {
    "auth/operation-not-allowed": "Phone sign-in is disabled in Firebase. Enable Authentication → Sign-in method → Phone, then try again.",
    "auth/billing-not-enabled": "Firebase SMS requires the Blaze billing plan. Upgrade the komiuta project in Firebase Console → Usage and billing, then retry.",
    "auth/invalid-phone-number": "That phone number looks invalid. Use the format +254 7XX XXX XXX.",
    "auth/too-many-requests": "Too many SMS attempts. Please wait a few minutes and try again.",
    "auth/quota-exceeded": "The SMS quota has been reached. Please use the email login code instead.",
    "auth/captcha-check-failed": "The security check failed. Please refresh the page and try again.",
    "auth/invalid-verification-code": "That code is not correct. Please check the SMS and try again.",
    "auth/code-expired": "That code has expired. Request a new SMS code.",
    "auth/missing-verification-code": "Enter the 6-digit code from the SMS.",
    "auth/network-request-failed": "Network error. Please check your connection and try again.",
  }

  return messages[code] || (error && error.message) || "Something went wrong. Please try again."
}
