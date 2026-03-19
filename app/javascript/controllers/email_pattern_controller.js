import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "dominio", "preview", "customField", "customInput"]
  static values = { patterns: Array }

  connect() {
    this.update()
  }

  update() {
    this.toggleCustomField()
    this.updatePreview()
  }

  toggleCustomField() {
    if (!this.hasCustomFieldTarget) return
    const isCustom = this.selectTarget.value === "custom"
    this.customFieldTarget.style.display = isCustom ? "" : "none"

    if (isCustom) {
      this.customInputTarget.name = "scuola[email_pattern]"
      this.selectTarget.name = ""
    } else {
      this.selectTarget.name = "scuola[email_pattern]"
      this.customInputTarget.name = ""
    }
  }

  updatePreview() {
    const pattern = this.selectTarget.value === "custom"
      ? (this.hasCustomInputTarget ? this.customInputTarget.value : "")
      : this.selectTarget.value
    const dominio = this.dominioTarget.value

    if (!pattern || !dominio) {
      this.previewTarget.textContent = ""
      return
    }

    const email = this.generateEmail("mario", "rossi", pattern, dominio)
    this.previewTarget.textContent = email ? `es. ${email}` : ""
  }

  generateEmail(nome, cognome, pattern, dominio) {
    let local
    switch (pattern) {
      case "nome.cognome": local = `${nome}.${cognome}`; break
      case "n.cognome": local = `${nome[0]}.${cognome}`; break
      case "cognome.nome": local = `${cognome}.${nome}`; break
      case "nomecognome": local = `${nome}${cognome}`; break
      case "cognomenome": local = `${cognome}${nome}`; break
      default: return null
    }
    return `${local}@${dominio}`
  }
}
