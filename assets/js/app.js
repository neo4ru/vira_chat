import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/vira_chat"
import topbar from "../vendor/topbar"

// Load the emoji picker from local node_modules instead of CDN
import "emoji-picker-element"

// --- Notification sounds (Web Audio API) ---
let audioCtx = null
function ensureAudioCtx() {
  if (!audioCtx) {
    const Ctx = window.AudioContext || window.webkitAudioContext
    if (!Ctx) return null
    audioCtx = new Ctx()
  }
  if (audioCtx.state === "suspended") audioCtx.resume()
  return audioCtx
}
function tone(freq, startAt, duration, gain = 0.08, type = "sine") {
  const ctx = ensureAudioCtx()
  if (!ctx) return
  const osc = ctx.createOscillator()
  const g = ctx.createGain()
  osc.type = type
  osc.frequency.value = freq
  g.gain.setValueAtTime(0, ctx.currentTime + startAt)
  g.gain.linearRampToValueAtTime(gain, ctx.currentTime + startAt + 0.01)
  g.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + startAt + duration)
  osc.connect(g)
  g.connect(ctx.destination)
  osc.start(ctx.currentTime + startAt)
  osc.stop(ctx.currentTime + startAt + duration + 0.02)
}
function playNotificationSound(kind = "message") {
  if (!ensureAudioCtx()) return
  if (kind === "mention") {
    tone(880, 0, 0.14, 0.10)
    tone(1320, 0.13, 0.18, 0.09)
  } else {
    tone(660, 0, 0.09, 0.07, "triangle")
    tone(880, 0.08, 0.12, 0.06, "triangle")
  }
}
window.addEventListener("phx:play_sound", (event) => {
  const kind = (event.detail && event.detail.kind) || "message"
  playNotificationSound(kind)
})
;["click", "keydown", "touchstart"].forEach((evt) => {
  window.addEventListener(evt, () => { ensureAudioCtx() }, { once: true })
})

// Apply saved theme before first paint
;(function () {
  try {
    const saved = localStorage.getItem("virachat-theme")
    const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches
    const theme = saved || (prefersDark ? "dark" : "light")
    document.documentElement.setAttribute("data-theme", theme)
  } catch (e) {}
})()

function urlBase64ToUint8Array(base64String) {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
  const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
  const rawData = window.atob(base64)
  const outputArray = new Uint8Array(rawData.length)
  for (let i = 0; i < rawData.length; ++i) outputArray[i] = rawData.charCodeAt(i)
  return outputArray
}

const Hooks = {}

Hooks.ScrollToBottom = {
  mounted() {
    this.el.scrollTop = this.el.scrollHeight
    this.btn = this.el.parentElement.querySelector("[data-scroll-btn]")
    this.updateBtn = () => {
      if (!this.btn) return
      const atBottom = this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight < 80
      if (atBottom) {
        this.btn.classList.add("hidden")
        this.btn.classList.remove("flex")
      } else {
        this.btn.classList.remove("hidden")
        this.btn.classList.add("flex")
      }
    }
    this.el.addEventListener("scroll", this.updateBtn)
    if (this.btn) {
      this.btn.addEventListener("click", () => {
        this.el.scrollTo({top: this.el.scrollHeight, behavior: "smooth"})
      })
    }
    this.updateBtn()
  },
  updated() {
    this.el.scrollTop = this.el.scrollHeight
    if (this.updateBtn) this.updateBtn()
  }
}

Hooks.EmojiPicker = {
  mounted() {
    const button = this.el.querySelector("[data-emoji-toggle]")
    const panel = this.el.querySelector("[data-emoji-panel]")
    const picker = this.el.querySelector("emoji-picker")
    const form = this.el.closest("form")
    const input = form ? form.querySelector("input[name='content']") : null
    
    if (!button || !panel || !input) return

    button.addEventListener("click", (e) => {
      e.preventDefault()
      panel.classList.toggle("hidden")
    })

    if (picker) {
      picker.addEventListener("emoji-click", (event) => {
        const emoji = event.detail.unicode
        
        // Insert at cursor position
        const startPos = input.selectionStart
        const endPos = input.selectionEnd
        input.value = input.value.substring(0, startPos) + emoji + input.value.substring(endPos, input.value.length)
        
        // Trigger LiveView
        input.focus()
        input.setSelectionRange(startPos + emoji.length, startPos + emoji.length)
        input.dispatchEvent(new Event("input", {bubbles: true}))
      })
    }

    document.addEventListener("click", (e) => {
      if (!this.el.contains(e.target)) panel.classList.add("hidden")
    })
  }
}

Hooks.Theme = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault()
      const html = document.documentElement
      const current = html.getAttribute("data-theme") || "light"
      const next = current === "dark" ? "light" : "dark"
      html.setAttribute("data-theme", next)
      try { localStorage.setItem("virachat-theme", next) } catch (err) {}
    })
  }
}

Hooks.CopyText = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault()
      const text = this.el.getAttribute("data-copy-text") || ""
      const done = () => {
        const original = this.el.innerHTML
        this.el.innerHTML = "✓"
        setTimeout(() => { this.el.innerHTML = original }, 1200)
      }
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(done).catch(() => {})
      } else {
        const ta = document.createElement("textarea")
        ta.value = text
        document.body.appendChild(ta)
        ta.select()
        try { document.execCommand("copy"); done() } catch (_) {}
        ta.remove()
      }
    })
  }
}

Hooks.AudioSpeed = {
  mounted() {
    const btn = this.el.querySelector("[data-speed-btn]")
    const audio = this.el.querySelector("audio")
    if (!btn || !audio) return
    const speeds = [1, 1.5, 2, 0.5]
    let idx = 0
    btn.addEventListener("click", (e) => {
      e.preventDefault()
      idx = (idx + 1) % speeds.length
      audio.playbackRate = speeds[idx]
      btn.textContent = speeds[idx] + "×"
    })
  }
}

Hooks.ImageLightbox = {
  mounted() {
    this.el.addEventListener("click", () => {
      const src = this.el.getAttribute("src")
      const overlay = document.createElement("div")
      overlay.className = "fixed inset-0 bg-black/90 z-50 flex items-center justify-center cursor-zoom-out p-4"
      overlay.innerHTML = `<img src="${src}" class="max-w-full max-h-full object-contain rounded-lg" />`
      const close = () => {
        overlay.remove()
        document.removeEventListener("keydown", onEsc)
      }
      const onEsc = (e) => { if (e.key === "Escape") close() }
      overlay.addEventListener("click", close)
      document.addEventListener("keydown", onEsc)
      document.body.appendChild(overlay)
    })
  }
}

Hooks.DraftMessages = {
  mounted() {
    const form = this.el.closest("form")
    const input = form ? form.querySelector("input[name='content']") : null
    if (!input) return
    const key = this.el.getAttribute("data-draft-key") || "virachat-draft"

    const saved = localStorage.getItem(key)
    if (saved) {
      input.value = saved
      input.dispatchEvent(new Event("input", {bubbles: true}))
    }

    input.addEventListener("input", () => {
      if (input.value.trim() === "") {
        localStorage.removeItem(key)
      } else {
        localStorage.setItem(key, input.value)
      }
    })

    form.addEventListener("submit", () => {
      localStorage.removeItem(key)
    })
  }
}

Hooks.MentionAutocomplete = {
  mounted() {
    const input = this.el.querySelector("input[name='content']")
    const panel = this.el.querySelector("[data-mention-panel]")
    if (!input || !panel) return
    const items = Array.from(panel.querySelectorAll("[data-mention-name]"))
    let highlighted = 0
    const hide = () => {
      panel.classList.add("hidden")
      highlighted = 0
      items.forEach((el) => el.classList.remove("bg-indigo-100", "dark:bg-indigo-900/40"))
    }
    const show = () => panel.classList.remove("hidden")
    const filter = (query) => {
      let any = false
      items.forEach((el) => {
        const name = el.getAttribute("data-mention-name").toLowerCase()
        const match = name.includes(query.toLowerCase())
        el.classList.toggle("hidden", !match)
        if (match) any = true
      })
      return any
    }
    const updateHighlight = (visible) => {
      visible.forEach((el, i) => {
        el.classList.toggle("bg-indigo-100", i === highlighted)
        el.classList.toggle("dark:bg-indigo-900/40", i === highlighted)
      })
    }
    const insert = (el) => {
      const name = el.getAttribute("data-mention-name")
      const value = input.value
      const atIndex = value.lastIndexOf("@")
      if (atIndex === -1) return
      input.value = value.slice(0, atIndex) + "@" + name + " "
      input.focus()
      input.dispatchEvent(new Event("input", {bubbles: true}))
      hide()
    }
    input.addEventListener("input", () => {
      const value = input.value
      const atIndex = value.lastIndexOf("@")
      if (atIndex === -1 || /\s/.test(value.slice(atIndex + 1))) { hide(); return }
      const before = atIndex > 0 ? value[atIndex - 1] : " "
      if (!/\s/.test(before) && atIndex > 0) { hide(); return }
      const query = value.slice(atIndex + 1)
      if (filter(query)) show(); else hide()
    })
    input.addEventListener("keydown", (e) => {
      if (panel.classList.contains("hidden")) return
      const visible = items.filter((el) => !el.classList.contains("hidden"))
      if (visible.length === 0) return
      if (e.key === "ArrowDown") { e.preventDefault(); highlighted = (highlighted + 1) % visible.length; updateHighlight(visible) }
      else if (e.key === "ArrowUp") { e.preventDefault(); highlighted = (highlighted - 1 + visible.length) % visible.length; updateHighlight(visible) }
      else if (e.key === "Enter" || e.key === "Tab") { e.preventDefault(); insert(visible[highlighted]) }
      else if (e.key === "Escape") { e.preventDefault(); hide() }
    })
    items.forEach((el) => {
      el.addEventListener("click", (e) => { e.preventDefault(); insert(el) })
    })
    document.addEventListener("click", (e) => {
      if (!this.el.contains(e.target)) hide()
    })
  }
}

Hooks.VoiceRecorder = {
  mounted() {
    const recordBtn = this.el.querySelector("[data-record-toggle]")
    const stopBtn = this.el.querySelector("[data-record-stop]")
    const timerEl = this.el.querySelector("[data-record-timer]")
    const indicator = this.el.querySelector("[data-record-indicator]")
    const form = this.el.closest("form")
    if (!recordBtn || !stopBtn || !timerEl || !indicator || !form) return
    
    let mediaRecorder = null
    let chunks = []
    let timerInterval = null
    let startTime = 0
    let pendingSubmit = false
    const formatTime = (ms) => {
      const s = Math.floor(ms / 1000)
      const m = Math.floor(s / 60).toString().padStart(2, "0")
      const ss = (s % 60).toString().padStart(2, "0")
      return `${m}:${ss}`
    }
    const startTimer = () => {
      startTime = Date.now()
      timerEl.textContent = "00:00"
      timerInterval = setInterval(() => {
        timerEl.textContent = formatTime(Date.now() - startTime)
      }, 200)
    }
    const stopTimer = () => { if (timerInterval) clearInterval(timerInterval); timerInterval = null }
    const hideIndicator = () => {
      indicator.classList.add("hidden")
      indicator.classList.remove("flex")
      recordBtn.classList.remove("hidden")
    }
    const attachFile = (blob) => {
      const ext = blob.type.includes("mpeg") || blob.type.includes("mp3") ? "mp3" : "webm"
      const file = new File([blob], `voice-${Date.now()}.${ext}`, {type: blob.type})
      const uploadInput = form.querySelector("input[type='file'][name='audio']")
      if (!uploadInput) return
      const dt = new DataTransfer()
      dt.items.add(file)
      uploadInput.files = dt.files
      uploadInput.dispatchEvent(new Event("change", {bubbles: true}))
      if (pendingSubmit) {
        pendingSubmit = false
        setTimeout(() => form.requestSubmit(), 150)
      }
    }
    recordBtn.addEventListener("click", async (e) => {
      e.preventDefault()
      if (!navigator.mediaDevices || !window.MediaRecorder) return
      try {
        const stream = await navigator.mediaDevices.getUserMedia({audio: true})
        const preferred = ["audio/webm;codecs=opus", "audio/webm", "audio/mpeg"]
        const mimeType = preferred.find((t) => MediaRecorder.isTypeSupported(t)) || ""
        mediaRecorder = new MediaRecorder(stream, mimeType ? {mimeType} : {})
        chunks = []
        mediaRecorder.ondataavailable = (ev) => { if (ev.data.size > 0) chunks.push(ev.data) }
        mediaRecorder.onstop = () => {
          stream.getTracks().forEach((t) => t.stop())
          const blob = new Blob(chunks, {type: mediaRecorder.mimeType || "audio/webm"})
          attachFile(blob)
        }
        mediaRecorder.start()
        indicator.classList.remove("hidden")
        indicator.classList.add("flex")
        recordBtn.classList.add("hidden")
        startTimer()
      } catch (err) {}
    })
    stopBtn.addEventListener("click", (e) => {
      e.preventDefault()
      if (mediaRecorder && mediaRecorder.state !== "inactive") mediaRecorder.stop()
      stopTimer()
      hideIndicator()
    })
    form.addEventListener("submit", (e) => {
      if (mediaRecorder && mediaRecorder.state === "recording") {
        e.preventDefault()
        e.stopImmediatePropagation()
        pendingSubmit = true
        mediaRecorder.stop()
        stopTimer()
        hideIndicator()
      }
    }, true)
  }
}

Hooks.EnablePush = {
  mounted() {
    this.el.addEventListener("click", (e) => { e.preventDefault(); this.enable() })
  },
  async enable() {
    if (!("serviceWorker" in navigator) || !("PushManager" in window)) return
    try {
      const permission = await Notification.requestPermission()
      if (permission !== "granted") return
      const reg = await navigator.serviceWorker.register("/sw.js", {scope: "/"})
      await navigator.serviceWorker.ready
      const vapidKey = document.querySelector("meta[name='vapid-public-key']").getAttribute("content")
      const sub = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(vapidKey)
      })
      this.pushEvent("push_subscribed", {subscription: sub.toJSON()})
    } catch (err) {}
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks}
})

topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

liveSocket.connect()
window.liveSocket = liveSocket

if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    reloader.enableServerLogs()
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if (keyDown === "c") { e.preventDefault(); e.stopImmediatePropagation(); reloader.openEditorAtCaller(e.target) }
      else if (keyDown === "d") { e.preventDefault(); e.stopImmediatePropagation(); reloader.openEditorAtDef(e.target) }
    }, true)
    window.liveReloader = reloader
  })
}