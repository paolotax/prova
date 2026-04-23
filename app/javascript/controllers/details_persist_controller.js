import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { key: String }

  connect() {
    this.restore = this.restore.bind(this)
    this.save = this.save.bind(this)
    this.element.addEventListener("toggle", this.save)
    document.addEventListener("turbo:morph", this.restore)
    this.restore()
  }

  disconnect() {
    this.element.removeEventListener("toggle", this.save)
    document.removeEventListener("turbo:morph", this.restore)
  }

  restore() {
    const stored = localStorage.getItem(this.keyValue)
    if (stored === "1") this.element.open = true
    else if (stored === "0") this.element.open = false
  }

  save() {
    localStorage.setItem(this.keyValue, this.element.open ? "1" : "0")
  }
}
