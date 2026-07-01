import { Controller } from "@hotwired/stimulus"

// Naviga un turbo-frame impostandone la src dal valore selezionato in un <select>.
// Uso: data-controller="frame-src" data-frame-src-frame-value="modal"
//   <select data-frame-src-target="select"> con <option value="/url/promozione">
//   <button data-action="frame-src#open">Aggiorna</button>
export default class extends Controller {
  static targets = ["select"]
  static values = { frame: { type: String, default: "modal" } }

  open() {
    const url = this.selectTarget.value
    if (!url) return
    const frame = document.getElementById(this.frameValue)
    if (frame) frame.src = url
  }
}
