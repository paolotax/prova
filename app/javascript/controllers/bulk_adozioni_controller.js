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

  // L'autofocus di showModal() arriva PRIMA che il controller hw-combobox sia
  // connesso (import async): l'input resta focused ma il gem non ha visto
  // l'evento focus e non apre/filtra. Blur+refocus rigenera l'evento quando
  // il controller c'è; retry breve finché il modulo non è connesso.
  connect() {
    this.#riarmaFocus(10)
  }

  #riarmaFocus(tentativi) {
    if (tentativi <= 0) return

    requestAnimationFrame(() => {
      const input = this.element.querySelector("input.hw-combobox__input")
      const connesso = input && this.application.getControllerForElementAndIdentifier(
        input.closest(".hw-combobox"), "hw-combobox"
      )

      if (!connesso) return setTimeout(() => this.#riarmaFocus(tentativi - 1), 100)

      if (document.activeElement === input) input.blur()
      input.focus()
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
