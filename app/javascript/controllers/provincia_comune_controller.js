import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["provincia", "comune", "sigla"]
  static values = { zone: Object }

  provinciaChanged() {
    const provincia = this.provinciaTarget.value
    const zoneData = this.zoneValue[provincia]

    // Aggiorna sigla
    if (this.hasSiglaTarget) {
      this.siglaTarget.value = zoneData?.sigla || ""
    }

    // Aggiorna comuni
    const currentComune = this.comuneTarget.value
    this.comuneTarget.innerHTML = '<option value="">—</option>'

    if (zoneData?.comuni) {
      zoneData.comuni.forEach(comune => {
        const option = document.createElement("option")
        option.value = comune
        option.textContent = comune
        if (comune === currentComune) option.selected = true
        this.comuneTarget.appendChild(option)
      })
    }
  }
}
