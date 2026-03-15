import { Controller } from "@hotwired/stimulus"

// Mostra/nasconde target "item" in base al valore della combobox.
// Usa data-action="hw-combobox:selection->reveal#update" sulla combobox.
//
// data-reveal-match-value="Classe:" (prefisso da matchare, default: "Classe:")
export default class extends Controller {
  static targets = ["item"]
  static values = {
    match: { type: String, default: "Classe:" }
  }

  update(event) {
    const value = event.detail?.value || ""
    const show = value.startsWith(this.matchValue)
    this.itemTargets.forEach(item => item.hidden = !show)
  }
}
