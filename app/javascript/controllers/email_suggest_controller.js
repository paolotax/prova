import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nome", "cognome", "email"]
  static values = { pattern: String, dominio: String, url: String }

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

  // Called when a destinatario is selected from combobox
  // Expects the combobox value in format "Scuola:uuid" or "Classe:uuid" etc.
  async fetchPattern(event) {
    const value = event.detail?.value || event.target?.value
    if (!value) return

    // Extract scuola id from appuntabile value (Scuola:uuid, Classe:uuid, Persona:uuid)
    const match = value.match(/^(Scuola|Classe|Persona):(.+)$/)
    if (!match) return

    const [, type, id] = match
    let scuolaId

    if (type === "Scuola") {
      scuolaId = id
    } else {
      // For Classe/Persona we need to resolve the scuola — skip for now
      // The pattern will be fetched when we know the scuola
      return
    }

    try {
      const url = this.urlValue.replace("__ID__", scuolaId)
      const response = await fetch(url, {
        headers: { "Accept": "application/json" }
      })
      if (!response.ok) return

      const data = await response.json()
      this.patternValue = data.pattern || ""
      this.dominioValue = data.dominio || ""
      this.manuallyEdited = false
      this.suggest()
    } catch {
      // silently fail
    }
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
