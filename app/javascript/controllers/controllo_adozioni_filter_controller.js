import { Controller } from "@hotwired/stimulus"

// Filtro client-side della lista unificata di controllo adozioni.
//
// Card KPI e step sono calcolati LATO SERVER (scope = provincia) e restano FISSI:
// contatori e visibilita' non cambiano mai. Cliccare una card o uno step aggiorna SOLO
// le righe visibili (nessuna query, nessun ricalcolo). Un solo filtro attivo per volta,
// in AND con la ricerca testo. Ri-cliccare il filtro attivo (o la card "tutte") azzera.
export default class extends Controller {
  static targets = ["row", "card", "step", "group", "scopeCount", "empty", "search"]

  // Chiavi filtro che coprono piu' stati-riga (data-filter composito).
  static COMPOSITES = { nuove: ["nuova", "verifica"] }

  connect() {
    this.filter = "all"
    this.q = ""
    // Dopo un morph (es. broadcast di una promozione) connect() NON riparte, ma il DOM e'
    // ricostruito dal server: il conteggio "scuole in lista" tornerebbe a 0 e l'highlight
    // sparirebbe. Ri-sincronizziamo sull'evento turbo:morph mantenendo il filtro attivo.
    this.resync = this.resync.bind(this)
    document.addEventListener("turbo:morph", this.resync)
    this.markActive()
    this.apply()
  }

  disconnect() {
    document.removeEventListener("turbo:morph", this.resync)
  }

  resync() {
    if (this.hasSearchTarget) this.q = this.searchTarget.value.trim().toLowerCase()
    this.markActive()
    this.apply()
  }

  // Card e step condividono la stessa dimensione: un solo filtro attivo. La card "tutte"
  // ha data-filter="all"; ri-cliccare il filtro attivo torna a "all".
  select(event) {
    const key = event.currentTarget.dataset.filter
    this.filter = this.filter === key ? "all" : key
    this.markActive()
    this.apply()
  }

  changeSearch(event) {
    this.q = event.target.value.trim().toLowerCase()
    this.apply()
  }

  // Evita che il click su un bottone d'azione dentro card/step scateni il filtro.
  stop(event) { event.stopPropagation() }

  markActive() {
    this.cardTargets.forEach(c => c.classList.toggle("analytics-summary__card--active", c.dataset.filter === this.filter))
    this.stepTargets.forEach(s => s.setAttribute("aria-current", String(s.dataset.filter === this.filter)))
  }

  matchFilter(row) {
    if (this.filter === "all") return true
    const keys = (row.dataset.filters || "").split(" ")
    const composite = this.constructor.COMPOSITES[this.filter]
    return composite ? composite.some(k => keys.includes(k)) : keys.includes(this.filter)
  }

  matchSearch(row) {
    return !this.q || (row.dataset.txt || "").includes(this.q)
  }

  apply() {
    // La ricerca testo cerca su TUTTE le righe, non solo su quelle del filtro attivo:
    // quando c'e' un testo prevale (ignora card/step); a campo vuoto torna il filtro.
    this.rowTargets.forEach(r => {
      r.hidden = this.q ? !this.matchSearch(r) : !this.matchFilter(r)
    })

    // Un gruppo direzione sparisce quando non ha righe visibili.
    this.groupTargets.forEach(g => {
      g.hidden = !Array.from(g.querySelectorAll(".ca-row")).some(r => !r.hidden)
    })

    const visible = this.rowTargets.filter(r => !r.hidden).length
    if (this.hasScopeCountTarget) this.scopeCountTarget.textContent = visible
    if (this.hasEmptyTarget) this.emptyTarget.style.display = visible ? "none" : "block"
  }
}
