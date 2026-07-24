import { Controller } from "@hotwired/stimulus"

// Inserimento multiplo adozioni: quando cambia la selezione delle classi, allinea
// il parametro anno_corso della src async della combobox libri (catalogo adozioni),
// cosi i titoli proposti sono quelli degli anni di corso selezionati.
//
// Robustezza: l'anno_corso di default e gia cotto nella src al render (classe del
// path); se il JS non gira, la combobox resta comunque filtrata su quell'anno.
export default class extends Controller {
  static values = { classiAnni: Object }

  static ASYNC_ATTR = "data-hw-combobox-async-src-value"

  // All'apertura showModal() manda il focus sul focus-trap nascosto di
  // hw-combobox, che inghiotte la digitazione: focus esplicito sull'input
  // visibile della prima combobox (classi).
  focusClassi() {
    requestAnimationFrame(() => {
      this.element.querySelector("input.hw-combobox__input")?.focus({ preventScroll: true })
    })
  }

  syncAnni() {
    const hidden = this.element.querySelector('input[name="classe_ids"]')
    const fieldset = this.element.querySelector(`[${this.constructor.ASYNC_ATTR}]`)
    if (!hidden || !fieldset) return

    const ids = (hidden.value || "").split(",").filter(Boolean)
    const anni = [...new Set(
      ids.map(id => this.classiAnniValue[id]).filter(Boolean)
    )]

    const url = new URL(fieldset.getAttribute(this.constructor.ASYNC_ATTR), window.location.origin)
    if (anni.length) {
      url.searchParams.set("anno_corso", anni.join(","))
    } else {
      url.searchParams.delete("anno_corso")
    }
    fieldset.setAttribute(this.constructor.ASYNC_ATTR, url.pathname + url.search)
  }
}
