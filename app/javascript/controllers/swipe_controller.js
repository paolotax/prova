import { Controller } from "@hotwired/stimulus"

// Swipe left/right to navigate prev/next pages on touch devices
// Usage: data-controller="swipe" with data-swipe-left-value="/prev" data-swipe-right-value="/next"
export default class extends Controller {
  static values = {
    left: String,
    right: String
  }

  connect() {
    this.touchStartX = 0
    this.touchStartY = 0
    this.handleTouchStart = this.#onTouchStart.bind(this)
    this.handleTouchEnd = this.#onTouchEnd.bind(this)
    this.element.addEventListener("touchstart", this.handleTouchStart, { passive: true })
    this.element.addEventListener("touchend", this.handleTouchEnd, { passive: true })
  }

  disconnect() {
    this.element.removeEventListener("touchstart", this.handleTouchStart)
    this.element.removeEventListener("touchend", this.handleTouchEnd)
  }

  #onTouchStart(event) {
    const touch = event.changedTouches[0]
    this.touchStartX = touch.screenX
    this.touchStartY = touch.screenY
  }

  #onTouchEnd(event) {
    const touch = event.changedTouches[0]
    const deltaX = touch.screenX - this.touchStartX
    const deltaY = touch.screenY - this.touchStartY

    // Must be mostly horizontal and at least 80px
    if (Math.abs(deltaX) < 80 || Math.abs(deltaY) > Math.abs(deltaX) * 0.5) return

    if (deltaX < 0 && this.hasRightValue) {
      Turbo.visit(this.rightValue)
    } else if (deltaX > 0 && this.hasLeftValue) {
      Turbo.visit(this.leftValue)
    }
  }
}
