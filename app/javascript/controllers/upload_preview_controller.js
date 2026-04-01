import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "fileName", "placeholder" ]

  previewFileName() {
    this.#file ? this.#showFileName() : this.#showPlaceholder()
  }

  #showFileName() {
    this.fileNameTarget.innerHTML = this.#file.name
    this.fileNameTarget.removeAttribute("hidden")
    this.placeholderTarget.setAttribute("hidden", true)
  }

  #showPlaceholder() {
    this.placeholderTarget.removeAttribute("hidden")
    this.fileNameTarget.setAttribute("hidden", true)
  }

  get #file() {
    return this.inputTarget.files[0]
  }
}
