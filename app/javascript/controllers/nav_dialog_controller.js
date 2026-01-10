import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  static values = {
    modal: { type: Boolean, default: false },
    autoOpen: { type: Boolean, default: false }
  }

  connect() {
    this.dialogTarget.setAttribute("aria-hidden", "true")
    if (this.autoOpenValue) this.open()
  }

  open() {
    if (this.modalValue) {
      this.dialogTarget.showModal()
    } else {
      this.dialogTarget.show()
    }

    this.loadLazyFrames()
    this.dialogTarget.setAttribute("aria-hidden", "false")
    this.dispatch("show")
  }

  toggle() {
    if (this.dialogTarget.open) {
      this.close()
    } else {
      this.open()
    }
  }

  close() {
    this.dialogTarget.close()
    this.dialogTarget.setAttribute("aria-hidden", "true")
    this.dialogTarget.blur()
    this.dispatch("close")
  }

  closeOnClickOutside({ target }) {
    if (!this.element.contains(target)) this.close()
  }

  loadLazyFrames() {
    Array.from(this.dialogTarget.querySelectorAll("turbo-frame")).forEach(frame => {
      frame.loading = "eager"
    })
  }

  captureKey(event) {
    if (event.key !== "Escape") {
      event.stopPropagation()
    }
  }
}
