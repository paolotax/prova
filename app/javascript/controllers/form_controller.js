import { Controller } from "@hotwired/stimulus"
import { debounce } from "helpers/timing_helpers";

export default class extends Controller {
  static targets = [ "cancel", "submit", "input" ]

  static values = {
    debounceTimeout: { type: Number, default: 300 }
  }

  initialize() {
    this.debouncedSubmit = debounce(this.debouncedSubmit.bind(this), this.debounceTimeoutValue)
  }

  submit() {
    this.element.requestSubmit()
  }

  // Submit + focus al prossimo input focusabile nella pagina.
  // Usa con: data-action="keydown.enter->form#submitAndFocusNext"
  submitAndFocusNext(event) {
    event.preventDefault()
    this.submit()
    const current = event.target
    const focusable = Array.from(
      document.querySelectorAll('input:not([type="hidden"]):not([disabled]), textarea:not([disabled]), select:not([disabled])')
    ).filter(el => el.offsetParent !== null)
    const idx = focusable.indexOf(current)
    const next = focusable[idx + 1]
    if (next) next.focus()
  }

  debouncedSubmit(event) {
    this.submit(event)
  }

  submitToTopTarget(event) {
    this.element.setAttribute("data-turbo-frame", "_top")
    this.submit()
  }

  reset() {
    this.element.reset()
  }

  select(event) {
    event.target.select()
  }

  cancel() {
    this.cancelTarget?.click()
  }
}
