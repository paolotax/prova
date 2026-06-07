import { Controller } from "@hotwired/stimulus"

// Tiene l'href del toggle vista (nell'header, fuori dal frame search_results)
// allineato ai filtri correnti: prende i parametri dall'URL e ci imposta la
// vista di destinazione. Senza questo, applicando un filtro nel frame l'header
// non viene rerenderizzato e il link conserva parametri stantii (perde i filtri).
export default class extends Controller {
  static values = { to: String }

  connect() {
    this.update()
    this.handler = this.onFrameLoad.bind(this)
    document.addEventListener("turbo:frame-load", this.handler)
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.handler)
  }

  onFrameLoad(event) {
    if (event.target.id === "search_results") this.update()
  }

  update() {
    const params = new URLSearchParams(window.location.search)
    params.set("vista", this.toValue)
    const base = this.element.href.split("?")[0]
    this.element.href = `${base}?${params.toString()}`
  }
}
