import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["collanaSelect", "targetContainer", "targetChip", "classiContainer", "classiChips", "classeChip"]
  static values = { classi: Array }

  targetChanged() {
    this.filterClassi()
  }

  filterClassi() {
    if (!this.hasClasseChipTarget) return

    const selectedTargets = this.getSelectedTargets()

    this.classeChipTargets.forEach(chip => {
      const anno = chip.dataset.anno
      if (selectedTargets.length === 0) {
        chip.style.display = ""
      } else {
        chip.style.display = selectedTargets.includes(anno) ? "" : "none"
      }
    })
  }

  getSelectedTargets() {
    return this.targetChipTargets
      .filter(chip => chip.querySelector("input").checked)
      .map(chip => chip.dataset.targetValue)
  }

  collanaChanged() {
    // Per ora il cambio collana richiede reload per aggiornare i target
    // In futuro si può fare via turbo frame
    const collanaId = this.collanaSelectTarget.value
    if (collanaId) {
      const url = new URL(window.location.href)
      url.searchParams.set("collana_id", collanaId)
      Turbo.visit(url.toString())
    }
  }
}
