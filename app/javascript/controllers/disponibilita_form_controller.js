import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "tipoSelect", "giornoField", "orarioFields",
    "dataField", "titoloField"
  ]

  static fieldMap = {
    orario:   { giorno: true,  orario: true,  data: false, titolo: false },
    chiusura: { giorno: false, orario: false, data: true,  titolo: true  },
    patrono:  { giorno: false, orario: false, data: true,  titolo: true  },
    seggio:   { giorno: false, orario: false, data: false, titolo: false },
    riunione: { giorno: true,  orario: true,  data: false, titolo: true  },
    nota:     { giorno: false, orario: false, data: true,  titolo: true  }
  }

  connect() {
    this.tipoChanged()
  }

  tipoChanged() {
    const tipo = this.tipoSelectTarget.value
    const fields = this.constructor.fieldMap[tipo] || {}

    if (this.hasGiornoFieldTarget)  this.giornoFieldTarget.hidden  = !fields.giorno
    if (this.hasOrarioFieldsTarget) this.orarioFieldsTarget.hidden = !fields.orario
    if (this.hasDataFieldTarget)    this.dataFieldTarget.hidden    = !fields.data
    if (this.hasTitoloFieldTarget)  this.titoloFieldTarget.hidden  = !fields.titolo
  }

  reset() {
    this.element.reset()
    this.tipoChanged()
  }
}
