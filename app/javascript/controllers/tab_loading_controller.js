import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.cleanup = this.cleanup.bind(this)
    document.addEventListener("turbo:before-cache", this.cleanup)
    document.addEventListener("turbo:before-render", this.cleanup)
    document.addEventListener("turbo:load", this.cleanup)
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.cleanup)
    document.removeEventListener("turbo:before-render", this.cleanup)
    document.removeEventListener("turbo:load", this.cleanup)
  }

  loading(event) {
    this.cleanup()
    event.currentTarget.classList.add("analytics-tabs__tab--loading")
  }

  cleanup() {
    this.element.querySelectorAll(".analytics-tabs__tab--loading")
      .forEach(el => el.classList.remove("analytics-tabs__tab--loading"))
  }
}
