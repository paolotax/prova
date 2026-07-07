import { Controller } from "@hotwired/stimulus"

// Filtro client-side della lista unificata di controllo adozioni.
// Combina: stato (step-card) AND ricerca testo. I contatori degli step si
// ricalcolano dalle righe che passano la ricerca (non lo stato). Alcuni step sono
// compositi: lo step "nuove" copre nuova + verifica.
export default class extends Controller {
  static targets = [
    "row", "step", "group",
    "scopeCount", "guideDone", "empty", "search"
  ]

  // Chiavi di stato che coprono più stati-riga (data-step-key composite).
  static COMPOSITES = { nuove: ["nuova", "verifica"] }

  connect() {
    this.filters = { stato: "all", q: "" }
    this.apply()
  }

  // Impostazione esplicita dello stato (usata dal pulsante "Da verificare" e,
  // via toggleStep, dalle step-card).
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

  changeSearch(event) { this.filters.q = event.target.value.trim().toLowerCase(); this.apply() }

  setStato(stato) {
    this.filters.stato = stato
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
    const q = this.filters.q
    return !q || (row.dataset.txt || "").includes(q)
  }

  apply() {
    this.rowTargets.forEach(r => { r.hidden = !(this.matchStato(r) && this.passRefine(r)) })

    this.groupTargets.forEach(g => {
      g.hidden = !Array.from(g.querySelectorAll(".ca-row")).some(r => !r.hidden)
    })

    const visible = this.rowTargets.filter(r => !r.hidden)
    if (this.hasScopeCountTarget) this.scopeCountTarget.textContent = visible.length
    if (this.hasEmptyTarget) this.emptyTarget.style.display = visible.length ? "none" : "block"

    // Contatori degli step: ricalcolati dalle righe che passano la ricerca (non lo stato).
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

    if (this.hasGuideDoneTarget) {
      this.guideDoneTarget.hidden = this.stepTargets.some(s => !s.hidden)
    }
  }
}
