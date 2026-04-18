import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "panel", "stepIndicator", "tipoInput", "titoloInput",
    "collanaField", "prevBtn", "nextBtn", "submitBtn"
  ]
  static values = { step: String }

  baseSteps = ["tipo", "info", "scuole", "riepilogo"]
  kitAdozioniSteps = ["tipo", "info", "libri", "scuole", "riepilogo"]

  get steps() {
    const tipo = this.selectedTipo()
    return tipo === "kit_adozioni" ? this.kitAdozioniSteps : this.baseSteps
  }

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

    this.updateStepIndicators()
  }

  nextStep() {
    const currentIndex = this.steps.indexOf(this.stepValue)
    if (currentIndex < 0) return

    if (this.stepValue === "tipo") {
      const selected = this.tipoInputTargets.find(i => i.checked)
      if (!selected) return
    }

    if (this.stepValue === "libri" && this.selectedLibriCount() === 0) return

    const nextStep = this.steps[currentIndex + 1]
    if (!nextStep) return

    if (nextStep === "libri") this.loadLibri()
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

    this.updateStepIndicators()

    if (this.hasPrevBtnTarget) this.prevBtnTarget.hidden = index === 0
    if (this.hasNextBtnTarget) this.nextBtnTarget.hidden = index === this.steps.length - 1
    if (this.hasSubmitBtnTarget) this.submitBtnTarget.hidden = index !== this.steps.length - 1

    if (step === "scuole") this.updateSchoolsChangeWarning()
  }

  updateStepIndicators() {
    const steps = this.steps
    const currentIndex = steps.indexOf(this.stepValue)

    this.stepIndicatorTargets.forEach(indicator => {
      const stepName = indicator.dataset.step
      const inSequence = steps.includes(stepName)
      indicator.hidden = !inSequence

      if (!inSequence) return

      const stepIndex = steps.indexOf(stepName)
      indicator.classList.toggle("wizard__step--active", stepName === this.stepValue)
      indicator.classList.toggle("wizard__step--completed", stepIndex < currentIndex)

      const numberEl = indicator.querySelector(".wizard__step-number")
      if (numberEl) numberEl.textContent = stepIndex + 1
    })
  }

  selectedTipo() {
    if (!this.hasTipoInputTarget) return null
    return this.tipoInputTargets.find(i => i.checked)?.value || null
  }

  selectedLibroIds() {
    return [...this.element.querySelectorAll('input[name="libro_ids[]"]:checked')].map(cb => cb.value)
  }

  selectedLibriCount() {
    return this.selectedLibroIds().length
  }

  selectedSchoolCount() {
    return this.selectedSchoolIds().length
  }

  selectedSchoolIds() {
    return [...this.element.querySelectorAll('input[name="school_ids[]"]:checked:not(:disabled)')].map(cb => cb.value)
  }

  updateSchoolsChangeWarning() {
    // Se sto tornando indietro su libri dopo aver già scelto scuole, aggiungo un confirm al bottone "Indietro".
    if (!this.hasPrevBtnTarget) return
    const isKit = this.selectedTipo() === "kit_adozioni"
    const hasSchools = this.selectedSchoolCount() > 0
    if (isKit && hasSchools) {
      this.prevBtnTarget.dataset.turboConfirm = "Cambiare i libri azzererà la selezione scuole. Continuare?"
    } else {
      delete this.prevBtnTarget.dataset.turboConfirm
    }
  }

  loadLibri() {
    const tipo = this.selectedTipo()
    if (tipo !== "kit_adozioni") return

    const params = new URLSearchParams({
      tipo_giro: tipo,
      titolo: this.titoloInputTarget?.value || ""
    })
    this.selectedLibroIds().forEach(id => params.append("libro_ids[]", id))

    const frame = this.element.querySelector("turbo-frame#wizard_libri")
    if (frame) {
      const basePath = window.location.pathname.replace(/\/giri\/wizard.*/, "/giri/wizard/libri")
      frame.src = null
      frame.loaded = Promise.resolve()
      frame.src = `${basePath}?${params}`
    }
  }

  loadScuole() {
    const tipo = this.selectedTipo()
    if (!tipo) return

    const params = new URLSearchParams({
      tipo_giro: tipo,
      collana_id: this.element.querySelector("[name=collana_id]")?.value || "",
      titolo: this.titoloInputTarget.value
    })
    this.selectedLibroIds().forEach(id => params.append("libro_ids[]", id))

    const frame = this.element.querySelector("turbo-frame#wizard_scuole")
    if (frame) {
      const basePath = window.location.pathname.replace(/\/giri\/wizard.*/, "/giri/wizard/scuole")
      frame.src = null
      frame.loaded = Promise.resolve()
      frame.src = `${basePath}?${params}`
    }
  }

  loadRiepilogo() {
    const tipo = this.selectedTipo()
    if (!tipo) return

    const params = new URLSearchParams({
      tipo_giro: tipo,
      collana_id: this.element.querySelector("[name=collana_id]")?.value || "",
      titolo: this.titoloInputTarget.value,
      scuole_count: this.selectedSchoolCount(),
      libri_count: this.selectedLibriCount()
    })
    this.selectedLibroIds().forEach(id => params.append("libro_ids[]", id))
    this.selectedSchoolIds().forEach(id => params.append("school_ids[]", id))

    const frame = this.element.querySelector("turbo-frame#wizard_riepilogo")
    if (frame) {
      const basePath = window.location.pathname.replace(/\/giri\/wizard.*/, "/giri/wizard/riepilogo")
      frame.src = null
      frame.loaded = Promise.resolve()
      frame.src = `${basePath}?${params}`
    }
  }

}
