import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    window.addEventListener("pageshow", this.#handlePageShow)
    document.addEventListener("turbo:load", this.#handleTurboLoad)
  }

  disconnect() {
    window.removeEventListener("pageshow", this.#handlePageShow)
    document.removeEventListener("turbo:load", this.#handleTurboLoad)
  }

  rememberLocation() {
    sessionStorage.setItem("referrerUrl", window.location.href)
  }

  backIfSamePath(event) {
    if (event.ctrlKey || event.metaKey || event.shiftKey) { return }

    const link = event.target.closest("a")
    const targetUrl = new URL(link.href)

    // Se il pathname corrisponde al referrer, usa history.back()
    // Preserva bfcache con infinite scroll e scroll position
    if (this.#referrerPath && targetUrl.pathname === this.#referrerPath) {
      event.preventDefault()
      // Salva l'ID dell'elemento corrente per refresh al ritorno
      const currentId = this.#extractIdFromPath(window.location.pathname)
      if (currentId) {
        sessionStorage.setItem("lastViewedId", currentId)
      }
      history.back()
    }
  }

  #handlePageShow = (event) => {
    // Se la pagina viene dal bfcache, aggiorna l'elemento modificato
    if (event.persisted) {
      this.#refreshLastViewedElement()
    }
  }

  #handleTurboLoad = (event) => {
    // Controlla se dobbiamo fare refresh dopo back navigation
    // Solo se siamo su una pagina lista (non show)
    const lastId = sessionStorage.getItem("lastViewedId")
    if (lastId && !window.location.pathname.includes(lastId)) {
      this.#refreshLastViewedElement()
    }
  }

  async #refreshLastViewedElement() {
    const lastId = sessionStorage.getItem("lastViewedId")
    if (!lastId) return

    sessionStorage.removeItem("lastViewedId")

    try {
      // Fetch della show con Accept turbo-stream per aggiornare l'elemento
      const accountId = this.#extractAccountId()
      const url = accountId ? `/${accountId}/appunti/${lastId}` : `/appunti/${lastId}`
      const response = await fetch(url, {
        headers: {
          "Accept": "text/vnd.turbo-stream.html"
        }
      })

      if (response.ok) {
        const html = await response.text()
        Turbo.renderStreamMessage(html)
      }
    } catch (error) {
      console.error("Failed to refresh element:", error)
    }
  }

  #extractIdFromPath(pathname) {
    // Estrae UUID o ID dal path (es. /appunti/uuid-here o /1/appunti/uuid-here)
    const match = pathname.match(/\/appunti\/([a-f0-9-]{36}|\d+)(?:\/|$)/i)
    return match ? match[1] : null
  }

  #extractAccountId() {
    // Estrae account_id dalla URL corrente (es. /uuid/appunti -> uuid o /1/appunti -> 1)
    const match = window.location.pathname.match(/^\/([a-f0-9-]{36}|\d+)\//i)
    return match ? match[1] : null
  }

  get #referrerPath() {
    if (!this.#referrerUrl) return null
    return new URL(this.#referrerUrl).pathname
  }

  get #referrerUrl() {
    return sessionStorage.getItem("referrerUrl")
  }
}
