import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "panel", "stepIndicator", "tipoInput", "titoloInput",
    "collanaField", "prevBtn", "nextBtn", "submitBtn",
    "schoolCheckbox", "schoolCount", "schoolList"
  ]
  static values = { step: String }

  // Step order
  steps = ["tipo", "info", "scuole", "riepilogo"]

  connect() {
    this.showStep(this.stepValue || "tipo")
  }

  selectTipo(e) {
    // Labels generate duplicate click events — ignore the one from the radio
    if (e.target.type === "radio") return

    const card = e.currentTarget
    const input = card.querySelector("input[type=radio]")
    if (!input) return

    input.checked = true

    // Visual selection
    this.element.querySelectorAll(".wizard__card").forEach(c => c.classList.remove("wizard__card--selected"))
    card.classList.add("wizard__card--selected")

    // Precompile titolo
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

    // Show/hide collana field
    if (this.hasCollanaFieldTarget) {
      const needsCollana = ["collane", "ritiro_collane"].includes(input.value)
      this.collanaFieldTarget.hidden = !needsCollana
    }
  }

  nextStep() {
    const currentIndex = this.steps.indexOf(this.stepValue)
    if (currentIndex < 0) return

    // Validation
    if (this.stepValue === "tipo") {
      const selected = this.tipoInputTargets.find(i => i.checked)
      if (!selected) return
    }

    const nextStep = this.steps[currentIndex + 1]
    if (!nextStep) return

    // Load scuole via Turbo Frame when entering step 3
    if (nextStep === "scuole") {
      this.loadScuole()
    }

    // Load riepilogo via Turbo Frame when entering step 4
    if (nextStep === "riepilogo") {
      this.loadRiepilogo()
    }

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

    // Show/hide panels
    this.panelTargets.forEach(panel => {
      panel.hidden = panel.dataset.step !== step
    })

    // Update step indicators
    this.stepIndicatorTargets.forEach(indicator => {
      const stepIndex = this.steps.indexOf(indicator.dataset.step)
      indicator.classList.toggle("wizard__step--active", indicator.dataset.step === step)
      indicator.classList.toggle("wizard__step--completed", stepIndex < index)
    })

    // Show/hide nav buttons
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

    const params = new URLSearchParams({
      tipo_giro: tipo,
      collana_id: this.element.querySelector("[name=collana_id]")?.value || "",
      titolo: this.titoloInputTarget.value
    })

    // Add selected school IDs
    this.schoolCheckboxTargets.filter(cb => cb.checked).forEach(cb => {
      params.append("school_ids[]", cb.value)
    })

    const frame = this.element.querySelector("turbo-frame#wizard_riepilogo")
    if (frame) {
      const basePath = window.location.pathname.replace(/\/giri\/wizard.*/, "/giri/wizard/riepilogo")
      frame.src = null
      frame.loaded = Promise.resolve()
      frame.src = `${basePath}?${params}`
    }
  }

  selectAllSchools() {
    this.schoolCheckboxTargets.forEach(cb => cb.checked = true)
    this.updateSchoolCount()
  }

  deselectAllSchools() {
    this.schoolCheckboxTargets.forEach(cb => cb.checked = false)
    this.updateSchoolCount()
  }

  updateSchoolCount() {
    const count = this.schoolCheckboxTargets.filter(cb => cb.checked).length
    if (this.hasSchoolCountTarget) {
      this.schoolCountTarget.textContent = count
    }
  }
}
