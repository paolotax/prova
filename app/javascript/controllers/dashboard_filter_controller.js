import { Controller } from "@hotwired/stimulus"

// Le card di analytics filtrano la tabella province: mostrano solo le righe con
// valore > 0 per la metrica scelta e, se la metrica ha un filtro operativo,
// riscrivono i link provincia perche' aprano il drill-down gia' filtrato.
// Re-click sulla card attiva = reset. Solo client-side: nessun round-trip.
export default class extends Controller {
  static targets = ["card", "row", "provinciaLink"]

  toggle(event) {
    const card = event.currentTarget.closest(".analytics-summary__card")
    const wasActive = card.classList.contains("analytics-summary__card--active")
    this.reset()
    if (wasActive) return

    card.classList.add("analytics-summary__card--active")
    const metric = card.dataset.metric
    this.rowTargets.forEach(row => {
      const counts = JSON.parse(row.dataset.counts || "{}")
      row.hidden = Number(counts[metric] || 0) <= 0
    })

    const filtro = card.dataset.filtro
    if (filtro) this.applyFiltro(filtro)
  }

  reset() {
    this.cardTargets.forEach(c => c.classList.remove("analytics-summary__card--active"))
    this.rowTargets.forEach(r => { r.hidden = false })
    this.provinciaLinkTargets.forEach(a => { a.href = a.dataset.baseHref })
  }

  applyFiltro(filtro) {
    this.provinciaLinkTargets.forEach(a => {
      const base = a.dataset.baseHref
      a.href = `${base}${base.includes("?") ? "&" : "?"}filtro=${encodeURIComponent(filtro)}`
    })
  }
}
