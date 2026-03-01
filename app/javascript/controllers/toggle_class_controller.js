import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static classes = [ "toggle" ]
  static targets = [ "checkbox" ]
  static values = { selector: String }

  get #target() {
    return this.hasSelectorValue
      ? document.querySelector(this.selectorValue)
      : this.element
  }

  toggle() {
    this.#target?.classList.toggle(this.toggleClass)
  }

  add() {
    this.#target?.classList.add(this.toggleClass)
  }

  remove() {
    this.#target?.classList.remove(this.toggleClass)
  }

  checkAll() {
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = true
    })
  }

  checkNone() {
    this.checkboxTargets.forEach(checkbox => {
      if (checkbox.dataset.boardsFormTarget === "meCheckbox") return
      checkbox.checked = false
    })
  }
}
