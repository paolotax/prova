import { Controller } from "@hotwired/stimulus"

const renderStream = (url) =>
  fetch(url, { headers: { "Accept": "text/vnd.turbo-stream.html" } })
    .then(r => r.ok ? r.text() : null)
    .then(html => html && Turbo.renderStreamMessage(html))
    .catch(e => console.error("Failed to refresh on back-navigation:", e))

// Riporta selezione/focus sull'elemento in lista da cui si è partiti, in modo
// deterministico tramite il controller navigable-list (no hover/mouseenter).
const selectInList = (elementId) => {
  requestAnimationFrame(() => {
    const el = document.getElementById(elementId)
    if (!el) return
    const listEl = el.closest("[data-controller~='navigable-list']")
    const controller = listEl && window.Stimulus?.getControllerForElementAndIdentifier(listEl, "navigable-list")
    if (controller) {
      controller.selectItem(el)
    } else {
      el.scrollIntoView({ block: "center" })
      el.focus({ preventScroll: true })
    }
  })
}

// Turbo scrolla in cima a fine visita, ma con le view transitions il reset
// arriva solo dopo la fine dell'animazione — o mai, se il browser scarta la
// transizione (es. view-transition-name duplicati con più pagine di righe
// caricate): la show resterebbe alla posizione di scroll della lista.
// Forza il top al render delle visit advance; restore (posizione ripristinata
// dalla history) e morph (refresh con scroll preserve) restano esclusi.
let lastVisitAction = null
document.addEventListener("turbo:visit", (event) => {
  lastVisitAction = event.detail?.action
})
document.addEventListener("turbo:render", (event) => {
  if (lastVisitAction === "advance" && event.detail?.renderMethod === "replace" && !window.location.hash) {
    window.scrollTo(0, 0)
  }
})
document.addEventListener("turbo:load", () => { lastVisitAction = null })

// La selezione (aria-selected) è stato UI transitorio: non deve finire nello
// snapshot in cache, altrimenti al ritorno la riga vista la volta prima viene
// ri-evidenziata per un istante prima di selezionare quella giusta (sfarfallio).
document.addEventListener("turbo:before-cache", () => {
  document.querySelectorAll('[aria-selected="true"]').forEach(el => el.removeAttribute("aria-selected"))
})

// Persistent listener — registered once at module load, never removed.
// Turbo replaces <body> but keeps <document>, so this survives all navigations.
document.addEventListener("turbo:load", () => {
  // Generic back-refresh: any show page can set <meta name="back-refresh-url">
  // with a turbo_stream URL that replaces its card in the list (e.g. libri).
  const refreshUrl = sessionStorage.getItem("lastBackRefreshUrl")
  if (refreshUrl) {
    sessionStorage.removeItem("lastBackRefreshUrl")
    const targetId = sessionStorage.getItem("lastBackRefreshTargetId")
    sessionStorage.removeItem("lastBackRefreshTargetId")
    const sep = refreshUrl.includes("?") ? "&" : "?"
    renderStream(`${refreshUrl}${sep}_=${Date.now()}`).then(() => {
      if (targetId) selectInList(targetId)
    })
  }

  // Entry-based refresh (appunti/documenti/tappe…)
  const entryId = sessionStorage.getItem("lastViewedEntryId")
  if (!entryId) return

  sessionStorage.removeItem("lastViewedEntryId")

  const match = window.location.pathname.match(/^\/([a-f0-9-]{36}|\d+)(?:\/|$)/i)
  if (!match) return

  // Su un index in vista tabella il nodo in lista è una riga, non una card:
  // chiedi al server la variante "row" (default per-risorsa se il cookie manca).
  const VISTA_DEFAULTS = { documenti: "tabella", appunti: "card" }
  let variant = ""
  const list = (window.location.pathname.match(/\/(documenti|appunti)(?:\/|$)/) || [])[1]
  if (list) {
    const vista = (document.cookie.match(new RegExp(`(?:^|;\\s*)${list}_vista=([^;]+)`)) || [])[1] || VISTA_DEFAULTS[list]
    if (vista === "tabella") variant = "&as=row"
  }

  renderStream(`/${match[1]}/entries/${entryId}?_=${Date.now()}${variant}`).then(() => {
    selectInList(`entry_${entryId}`)
  })
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
        const targetId = document.querySelector('meta[name="back-refresh-target"]')?.content
        if (targetId) {
          sessionStorage.setItem("lastBackRefreshTargetId", targetId)
        }
      }
      sessionStorage.removeItem("referrerUrl")

      // After documento save (full page reload), history has a duplicate show entry
      const fullReload = sessionStorage.getItem("fullReloadSave")
      sessionStorage.removeItem("fullReloadSave")
      history.go(fullReload ? -2 : -1)
    }
  }
}
