// ViraChat service worker — PWA install, asset caching, push notifications.

const CACHE = "virachat-v2"
const PRECACHE = [
  "/assets/css/app.css",
  "/assets/js/app.js",
  "/images/icons/icon-192.png",
  "/images/logo.svg"
]

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(PRECACHE)).catch(() => {})
  )
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  )
})

// Network-first for app assets with a cache fallback; everything else live.
self.addEventListener("fetch", (event) => {
  const request = event.request

  if (request.method !== "GET") return

  const url = new URL(request.url)
  if (url.origin !== self.location.origin) return

  const isAsset = url.pathname.startsWith("/assets/") || url.pathname.startsWith("/images/")
  if (!isAsset) return

  event.respondWith(
    fetch(request)
      .then((response) => {
        if (response && response.ok) {
          const copy = response.clone()
          caches.open(CACHE).then((cache) => cache.put(request, copy))
        }
        return response
      })
      .catch(() => caches.match(request))
  )
})

self.addEventListener("push", (event) => {
  let data = { title: "ViraChat", body: "New message", url: "/chat" }

  if (event.data) {
    try {
      data = Object.assign(data, event.data.json())
    } catch (e) {
      data.body = event.data.text()
    }
  }

  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((clients) => {
      // If a ViraChat window is focused, skip the notification.
      const focused = clients.some((c) => c.focused)
      if (focused) return

      return self.registration.showNotification(data.title, {
        body: data.body,
        icon: "/images/icons/icon-192.png",
        badge: "/images/icons/icon-192.png",
        data: { url: data.url }
      })
    })
  )
})

self.addEventListener("notificationclick", (event) => {
  event.notification.close()
  const targetUrl = (event.notification.data && event.notification.data.url) || "/chat"

  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((clients) => {
      for (const client of clients) {
        if (client.url.includes("/chat") && "focus" in client) {
          client.navigate(targetUrl)
          return client.focus()
        }
      }
      return self.clients.openWindow(targetUrl)
    })
  )
})
