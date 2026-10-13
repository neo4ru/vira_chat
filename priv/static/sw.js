// ViraChat service worker — handles push events and notification clicks.

self.addEventListener("install", (event) => {
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim())
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
        icon: "/images/logo.svg",
        badge: "/images/logo.svg",
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