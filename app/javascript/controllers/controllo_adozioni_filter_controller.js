import { Controller } from "@hotwired/stimulus"

// Filtro client-side della lista unificata di controllo adozioni.
// Combina: stato (chip o step) AND provincia AND grado AND ricerca testo.
// I contatori di chip e step si ricalcolano dalle righe che passano provincia/grado/ricerca
// (non lo stato). Alcuni step sono compositi: lo step "nuove" copre nuova + verifica.
export default class extends Controller {
  static targets = [
    "row", "step", "chip", "group",
    "scopeCount", "guideDone", "empty",
    "prov", "grado", "search"
  ]

  // Chiavi di stato che coprono più stati-riga (data-step-key composite).
  static COMPOSITES = { nuove: ["nuova", "verifica"] }

  connect() {
    this.filters = { stato: "all", prov: "all", grado: "all", q: "" }
    this.apply()
  }

  selectChip(event) {
    this.setStato(event.currentTarget.dataset.filter)
  }

  toggleStep(event) {
    const key = event.currentTarget.dataset.stepKey
    this.setStato(this.filters.stato === key ? "all" : key)
  }

  // Evita che il click su un bottone d'azione dentro la card faccia scattare il filtro.
  stop(event) {
    event.stopPropagation()
  }

  changeProv(event)  { this.filters.prov = event.target.value; this.apply() }
  changeGrado(event) { this.filters.grado = event.target.value; this.apply() }
  changeSearch(event) { this.filters.q = event.target.value.trim().toLowerCase(); this.apply() }

  setStato(stato) {
    this.filters.stato = stato
    this.chipTargets.forEach(c => c.setAttribute("aria-pressed", String(c.dataset.filter === stato)))
    this.stepTargets.forEach(s => s.setAttribute("aria-current", String(s.dataset.stepKey === stato)))
    this.apply()
  }

  matchStato(row) {
    const s = this.filters.stato
    if (s === "all") return true
    const composite = this.constructor.COMPOSITES[s]
    if (composite) return composite.includes(row.dataset.state)
    return row.dataset.state === s
  }

  passRefine(row) {
    const f = this.filters
    return (f.prov === "all" || row.dataset.prov === f.prov)
      && (f.grado === "all" || row.dataset.grado === f.grado)
      && (!f.q || (row.dataset.txt || "").includes(f.q))
  }

  apply() {
    this.rowTargets.forEach(r => { r.hidden = !(this.matchStato(r) && this.passRefine(r)) })

    this.groupTargets.forEach(g => {
      g.hidden = !Array.from(g.querySelectorAll(".ca-row")).some(r => !r.hidden)
    })

    const visible = this.rowTargets.filter(r => !r.hidden)
    if (this.hasScopeCountTarget) this.scopeCountTarget.textContent = visible.length
    if (this.hasEmptyTarget) this.emptyTarget.style.display = visible.length ? "none" : "block"

    // Contatori: ricalcolati dalle righe che passano i refine (ignorando lo stato).
    const base = this.rowTargets.filter(r => this.passRefine(r))
    const count = (key) => {
      if (key === "all") return base.length
      const composite = this.constructor.COMPOSITES[key]
      if (composite) return base.filter(r => composite.includes(r.dataset.state)).length
      return base.filter(r => r.dataset.state === key).length
    }

    this.stepTargets.forEach(s => {
      const n = count(s.dataset.stepKey)
      const el = s.querySelector("[data-count]")
      if (el) el.textContent = n
      s.hidden = (n === 0)
    })

    this.chipTargets.forEach(c => {
      const el = c.querySelector("[data-count]")
      if (el) el.textContent = count(c.dataset.filter)
    })

    if (this.hasGuideDoneTarget) {
      this.guideDoneTarget.hidden = this.stepTargets.some(s => !s.hidden)
    }
  }
}
