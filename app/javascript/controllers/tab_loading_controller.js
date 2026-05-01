import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.cleanup = this.cleanup.bind(this)
    this.markActiveLoading = this.markActiveLoading.bind(this)
    document.addEventListener("turbo:load", this.cleanup)
    document.addEventListener("turbo:submit-start", this.markActiveLoading)
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.cleanup)
    document.removeEventListener("turbo:submit-start", this.markActiveLoading)
  }

  loading(event) {
    this.cleanup()
    event.currentTarget.classList.add("analytics-tabs__tab--loading")
    this.markFormBusy()
  }

  resetClicked() {
    this.markActiveTab()
  }

  markActiveLoading(event) {
    const form = event.detail?.formSubmission?.formElement
    if (!form?.classList.contains("analytics-filters")) return
    this.markActiveTab()
  }

  markActiveTab() {
    this.cleanup()
    const active = this.element.querySelector(".analytics-tabs__tab--active")
    if (active) active.classList.add("analytics-tabs__tab--loading")
    this.markFormBusy()
  }

  markFormBusy() {
    const form = this.element.querySelector(".analytics-filters")
    if (form) form.setAttribute("aria-busy", "true")
  }

  cleanup() {
    this.element.querySelectorAll(".analytics-tabs__tab--loading")
      .forEach(el => el.classList.remove("analytics-tabs__tab--loading"))
    const form = this.element.querySelector(".analytics-filters[aria-busy]")
    if (form) form.removeAttribute("aria-busy")
  }
}
