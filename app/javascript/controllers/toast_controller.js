import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { timeout: { type: Number, default: 5000 } }

  connect() {
    this.timer = setTimeout(() => this.element.remove(), this.timeoutValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
