import { Controller } from "@hotwired/stimulus"
import { debounce } from "helpers/timing_helpers";
import { post } from "@rails/request.js"

export default class extends Controller {
  static classes = ["filtersSet"]
  static targets = ["field", "form"]
  static values = { noFilteringUrl: String, refreshUrl: String, frameId: { type: String, default: "scuole_list" } }

  initialize() {
    this.debouncedToggle = debounce(this.#toggle.bind(this), 50)
    this.debouncedRefresh = debounce(this.#refreshSaveToggleButton.bind(this), 500)
  }

  connect() {
    this.#toggle()
  }

  change(event) {
    this.#toggle()
    this.#refreshSaveToggleButton()
  }

  // Called on search input - debounced refresh
  searchChange(event) {
    this.#toggle()
    this.debouncedRefresh()
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

  #refreshSaveToggleButton() {
    if (!this.hasRefreshUrlValue) return

    post(this.refreshUrlValue, {
      body: this.#collectFilterFormData(),
      responseKind: "turbo-stream"
    })
  }

  #collectFilterFormData() {
    const formData = new FormData()

    if (this.hasFormTarget) {
      // Collect all hidden fields (like Fizzy does)
      const hiddenFields = this.formTarget.querySelectorAll('input[type="hidden"]:not([disabled])[name]')
      hiddenFields.forEach(field => {
        formData.append(field.name, field.value)
      })

      // Also collect search/text fields that have values
      const textFields = this.formTarget.querySelectorAll('input[type="search"][name], input[type="text"][name]')
      textFields.forEach(field => {
        if (field.value?.trim()) {
          formData.append(field.name, field.value.trim())
        }
      })
    }

    return formData
  }
}
