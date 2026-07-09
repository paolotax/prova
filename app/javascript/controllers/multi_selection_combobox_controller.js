import { Controller } from "@hotwired/stimulus"
import { toSentence } from "helpers/text_helpers"

export default class extends Controller {
  static targets = [ "label", "item", "hiddenFieldTemplate" ]
  static values = {
    selectPropertyName: { type: String, default: "aria-checked" },
    defaultValue: String,
    noSelectionLabel: { type: String, default: "No selection" },
    labelPrefix: String
  }

  connect() {
    this.refresh()
    this.#takeSnapshot()
  }

  change(event) {
    const item = event.target.closest("[role='checkbox']")
    if (item) {
      this.#toggleSelection(item)
    }
  }

  apply() {
    this.refresh()
    this.#takeSnapshot()
  }

  restore() {
    if (!this.appliedState) return

    this.itemTargets.forEach(item => {
      item.setAttribute(this.selectPropertyNameValue, this.appliedState.has(item))
    })
    this.refresh()
  }

  refresh() {
    this.labelTarget.textContent = this.#selectedLabel
    this.#updateHiddenFields()
    this.#updateFilterShow()
  }

  clear(event) {
    this.#deselectAll()
    this.refresh()
  }

  get #selectedLabel() {
    const selectedValues = this.#selectedValues()
    if (selectedValues.length === 0) {
      return this.noSelectionLabelValue
    }

    const labels = this.#selectedItems.map(item => item.dataset.multiSelectionComboboxLabel)
    const sentence = toSentence(labels, {
      two_words_connector: " o ",
      last_word_connector: " o "
    })

    return this.hasLabelPrefixValue ? `${this.labelPrefixValue} ${sentence}` : sentence
  }

  #toggleSelection(item) {
    const isSelected = item.getAttribute(this.selectPropertyNameValue) === "true"

    if (isSelected) {
      item.setAttribute(this.selectPropertyNameValue, "false")
    } else {
      if (this.isAnExclusiveSelectionItemInvolved(item)) {
        this.#deselectAll()
      }

      item.setAttribute(this.selectPropertyNameValue, "true")
    }

    this.#updateHiddenFields()
  }

  isAnExclusiveSelectionItemInvolved(item) {
    return this.#isExclusiveSelection(item) || Array.from(this.#selectedItems).some((item) => this.#isExclusiveSelection(item))
  }

  #isExclusiveSelection(item) {
    return item.dataset.multiSelectionExclusive === "true"
  }

  #updateHiddenFields() {
    this.#clearHiddenFields()
    this.#addHiddenFields()
  }

  #deselectAll() {
    this.itemTargets.forEach(item => {
      item.setAttribute(this.selectPropertyNameValue, "false")
    })
  }

  get #selectedItems() {
    return this.itemTargets.filter(item =>
      item.getAttribute(this.selectPropertyNameValue) === "true"
    )
  }

  #selectedValues() {
    return this.#selectedItems.map(item => item.dataset.multiSelectionComboboxValue)
  }

  #clearHiddenFields() {
    this.#hiddenFields.forEach(field => {
      field.remove()
    })
  }

  get #hiddenFields() {
    return this.element.querySelectorAll("input[type='hidden']")
  }

  #addHiddenFields() {
    this.#selectedItems.forEach(item => {
      const [ field ] = this.hiddenFieldTemplateTarget.content.cloneNode(true).children
      field.removeAttribute("id")
      field.value = item.dataset.multiSelectionComboboxValue
      if (item.dataset.multiSelectionComboboxFieldName) {
        field.setAttribute("name", item.dataset.multiSelectionComboboxFieldName)
      }
      this.element.appendChild(field)
    })
  }

  #updateFilterShow() {
    const hasSelection = this.#selectedValues().length > 0
    this.element.setAttribute("data-filter-show", hasSelection)
  }

  #takeSnapshot() {
    this.appliedState = new Set(this.#selectedItems)
  }
}
