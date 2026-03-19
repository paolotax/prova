import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nome", "cognome", "email"]
  static values = { pattern: String, dominio: String }

  suggest() {
    const nome = this.nomeTarget.value.trim()
    const cognome = this.cognomeTarget.value.trim()
    const pattern = this.patternValue
    const dominio = this.dominioValue

    if (!nome || !cognome || !pattern || !dominio) return
    if (this.manuallyEdited) return

    const email = this.generateEmail(
      this.normalize(nome),
      this.normalize(cognome),
      pattern,
      dominio
    )
    if (email) this.emailTarget.value = email
  }

  markManual() {
    this.manuallyEdited = true
  }

  clearManual() {
    this.manuallyEdited = false
    this.suggest()
  }

  normalize(str) {
    return str
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/[^a-zA-Z]/g, "")
      .toLowerCase()
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
