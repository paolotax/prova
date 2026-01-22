import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "item", "counter" ]
  static values = {
    propertyName: { type: String, default: "--card-count" },
    maxValue: { type: Number, default: 15 }
  }

  initialize() {
    this.#updateCounter = this.#debounce(this.#updateCounter.bind(this), 50)
  }

  connect() {
    if (this.itemTargets.length > 0) {
      this.#updateCounter()
    }
  }

  itemTargetConnected() {
    this.#updateCounter()
  }

  itemTargetDisconnected() {
    this.#updateCounter()
  }

  #updateCounter = () => {
    if (!this.hasCounterTarget) return
    const count = Math.min(this.itemTargets.length, this.maxValueValue)
    this.counterTarget.style.setProperty(this.propertyNameValue, count)
  }

  #debounce(fn, delay) {
    let timeoutId
    return (...args) => {
      clearTimeout(timeoutId)
      timeoutId = setTimeout(() => fn(...args), delay)
    }
  }
}
