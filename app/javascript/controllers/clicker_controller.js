import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["clickable"]

  async click() {
    await this.#nextFrame()
    this.#clickable.click()
  }

  get #clickable() {
    return this.hasClickableTarget ? this.clickableTarget : this.element
  }

  #nextFrame() {
    return new Promise(requestAnimationFrame)
  }
}
