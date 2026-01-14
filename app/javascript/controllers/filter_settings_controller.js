import { Controller } from "@hotwired/stimulus"
import { debounce } from "helpers/timing_helpers";

export default class extends Controller {
  static classes = ["filtersSet"]
  static targets = ["field", "form"]
  static values = { noFilteringUrl: String, frameId: { type: String, default: "scuole_list" } }

  initialize() {
    this.debouncedToggle = debounce(this.#toggle.bind(this), 50)
  }

  connect() {
    this.#toggle()
  }

  change(event) {
    this.#toggle()
  }

  resetIfNoFiltering(event) {
    if (!this.#hasFiltersSet) {
      this.#showNoFilteringUrl()
      event.stopImmediatePropagation()
    }
  }

  async fieldTargetConnected(field) {
    this.debouncedToggle()
  }

  #toggle() {
    this.element.classList.toggle(this.filtersSetClass, this.#hasFiltersSet)
  }

  get #hasFiltersSet() {
    return this.fieldTargets.some(field => this.#isFieldSet(field))
  }

  #isFieldSet(field) {
    const value = field.value?.trim()

    if (!value) return false

    const defaultValue = this.#defaultValueForField(field)
    return defaultValue ? value !== defaultValue : true
  }

  #defaultValueForField(field) {
    const comboboxContainer = field.closest("[data-combobox-default-value-value]")
    return comboboxContainer?.dataset?.comboboxDefaultValueValue
  }

  #showNoFilteringUrl() {
    Turbo.visit(this.noFilteringUrlValue, { frame: this.frameIdValue, action: "advance" })
  }
}
