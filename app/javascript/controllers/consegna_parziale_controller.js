import { Controller } from "@hotwired/stimulus"

// Consegna parziale dal dialog Gestione documento: pannello con quantità
// per riga e totale vivo sul bottone di submit. A pannello chiuso gli input
// sono disabled, il form non manda righe[] e il server consegna tutto il
// residuo (fast path).
export default class extends Controller {
  static targets = ["panel", "input", "totale", "submit", "toggle"]

  connect() {
    this.residuoTotale = parseInt(this.totaleTarget.textContent, 10) || 0
  }

  toggle() {
    const apri = this.panelTarget.hidden
    this.panelTarget.hidden = !apri
    this.inputTargets.forEach(input => input.disabled = !apri)
    this.toggleTarget.textContent = apri ? "Tutto il residuo" : "Parziale…"
    if (apri) this.inputTargets[0]?.focus()
    this.ricalcola()
  }

  ricalcola() {
    if (!this.hasPanelTarget || this.panelTarget.hidden) {
      this.totaleTarget.textContent = this.residuoTotale
      this.submitTarget.disabled = this.residuoTotale === 0
      return
    }

    let totale = 0
    this.inputTargets.forEach(input => {
      const max = parseInt(input.max, 10) || 0
      let valore = parseInt(input.value, 10) || 0
      if (valore < 0) { valore = 0; input.value = "" }
      if (valore > max) { valore = max; input.value = max }
      totale += valore
    })
    this.totaleTarget.textContent = totale
    this.submitTarget.disabled = totale === 0
  }
}
