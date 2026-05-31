import { Controller } from "@hotwired/stimulus"

const renderStream = (url) =>
  fetch(url, { headers: { "Accept": "text/vnd.turbo-stream.html" } })
    .then(r => r.ok ? r.text() : null)
    .then(html => html && Turbo.renderStreamMessage(html))
    .catch(e => console.error("Failed to refresh on back-navigation:", e))

// Persistent listener — registered once at module load, never removed.
// Turbo replaces <body> but keeps <document>, so this survives all navigations.
document.addEventListener("turbo:load", () => {
  // Generic back-refresh: any show page can set <meta name="back-refresh-url">
  // with a turbo_stream URL that replaces its card in the list (e.g. libri).
  const refreshUrl = sessionStorage.getItem("lastBackRefreshUrl")
  if (refreshUrl) {
    sessionStorage.removeItem("lastBackRefreshUrl")
    const sep = refreshUrl.includes("?") ? "&" : "?"
    renderStream(`${refreshUrl}${sep}_=${Date.now()}`)
  }

  // Entry-based refresh (appunti/documenti/tappe…)
  const entryId = sessionStorage.getItem("lastViewedEntryId")
  if (!entryId) return

  sessionStorage.removeItem("lastViewedEntryId")

  const match = window.location.pathname.match(/^\/([a-f0-9-]{36}|\d+)(?:\/|$)/i)
  if (!match) return

  renderStream(`/${match[1]}/entries/${entryId}?_=${Date.now()}`)
})

export default class extends Controller {
  rememberLocation(event) {
    // Skip same-page refreshes (e.g., broadcast morph after save)
    const destination = event.detail?.url
    if (destination && new URL(destination).pathname === window.location.pathname) return

    sessionStorage.setItem("referrerUrl", window.location.href)
  }

  backIfSamePath(event) {
    if (event.ctrlKey || event.metaKey || event.shiftKey) return

    const referrerUrl = sessionStorage.getItem("referrerUrl")
    if (referrerUrl) {
      event.preventDefault()
      const entryId = document.querySelector('meta[name="entry-id"]')?.content
      if (entryId) {
        sessionStorage.setItem("lastViewedEntryId", entryId)
      }
      const refreshUrl = document.querySelector('meta[name="back-refresh-url"]')?.content
      if (refreshUrl) {
        sessionStorage.setItem("lastBackRefreshUrl", refreshUrl)
      }
      sessionStorage.removeItem("referrerUrl")

      // After documento save (full page reload), history has a duplicate show entry
      const fullReload = sessionStorage.getItem("fullReloadSave")
      sessionStorage.removeItem("fullReloadSave")
      history.go(fullReload ? -2 : -1)
    }
  }
}
