import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "panel", "stepIndicator", "tipoInput", "titoloInput",
    "collanaField", "prevBtn", "nextBtn", "submitBtn"
  ]
  static values = { step: String }

  steps = ["tipo", "info", "scuole", "riepilogo"]

  connect() {
    this.showStep(this.stepValue || "tipo")
  }

  selectTipo(e) {
    if (e.target.type === "radio") return

    const option = e.currentTarget
    const input = option.querySelector("input[type=radio]")
    if (!input) return

    input.checked = true

    this.element.querySelectorAll(".wizard__option").forEach(c => c.classList.remove("wizard__option--selected"))
    option.classList.add("wizard__option--selected")

    const labels = {
      kit_adozioni: "Kit Adozioni",
      collane: "Collane",
      ritiro_collane: "Ritiro Collane",
      consegne: "Consegne",
      visite: "Visite"
    }
    if (this.hasTitoloInputTarget) {
      this.titoloInputTarget.value = labels[input.value] || ""
    }

    if (this.hasCollanaFieldTarget) {
      const needsCollana = ["collane", "ritiro_collane"].includes(input.value)
      this.collanaFieldTarget.hidden = !needsCollana
    }
  }

  nextStep() {
    const currentIndex = this.steps.indexOf(this.stepValue)
    if (currentIndex < 0) return

    if (this.stepValue === "tipo") {
      const selected = this.tipoInputTargets.find(i => i.checked)
      if (!selected) return
    }

    const nextStep = this.steps[currentIndex + 1]
    if (!nextStep) return

    if (nextStep === "scuole") this.loadScuole()
    if (nextStep === "riepilogo") this.loadRiepilogo()

    this.showStep(nextStep)
  }

  prevStep() {
    const currentIndex = this.steps.indexOf(this.stepValue)
    if (currentIndex <= 0) return
    this.showStep(this.steps[currentIndex - 1])
  }

  showStep(step) {
    this.stepValue = step
    const index = this.steps.indexOf(step)

    this.panelTargets.forEach(panel => {
      panel.hidden = panel.dataset.step !== step
    })

    this.stepIndicatorTargets.forEach(indicator => {
      const stepIndex = this.steps.indexOf(indicator.dataset.step)
      indicator.classList.toggle("wizard__step--active", indicator.dataset.step === step)
      indicator.classList.toggle("wizard__step--completed", stepIndex < index)
    })

    if (this.hasPrevBtnTarget) this.prevBtnTarget.hidden = index === 0
    if (this.hasNextBtnTarget) this.nextBtnTarget.hidden = index === this.steps.length - 1
    if (this.hasSubmitBtnTarget) this.submitBtnTarget.hidden = index !== this.steps.length - 1
  }

  loadScuole() {
    const tipo = this.tipoInputTargets.find(i => i.checked)?.value
    if (!tipo) return

    const params = new URLSearchParams({
      tipo_giro: tipo,
      collana_id: this.element.querySelector("[name=collana_id]")?.value || "",
      titolo: this.titoloInputTarget.value
    })

    const frame = this.element.querySelector("turbo-frame#wizard_scuole")
    if (frame) {
      const basePath = window.location.pathname.replace(/\/giri\/wizard.*/, "/giri/wizard/scuole")
      frame.src = null
      frame.loaded = Promise.resolve()
      frame.src = `${basePath}?${params}`
    }
  }

  loadRiepilogo() {
    const tipo = this.tipoInputTargets.find(i => i.checked)?.value
    if (!tipo) return

    const checkedCount = this.element
      .querySelectorAll('input[name="school_ids[]"]:checked:not(:disabled)').length

    const params = new URLSearchParams({
      tipo_giro: tipo,
      collana_id: this.element.querySelector("[name=collana_id]")?.value || "",
      titolo: this.titoloInputTarget.value,
      scuole_count: checkedCount
    })

    const frame = this.element.querySelector("turbo-frame#wizard_riepilogo")
    if (frame) {
      const basePath = window.location.pathname.replace(/\/giri\/wizard.*/, "/giri/wizard/riepilogo")
      frame.src = null
      frame.loaded = Promise.resolve()
      frame.src = `${basePath}?${params}`
    }
  }
}
