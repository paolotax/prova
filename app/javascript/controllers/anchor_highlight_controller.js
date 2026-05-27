import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const hash = window.location.hash
    if (!hash || hash.length < 2) return

    const target = this.element.querySelector(hash)
    if (!target) return

    target.scrollIntoView({ behavior: "smooth", block: "center" })
    target.classList.add("is-flashing")
    setTimeout(() => target.classList.remove("is-flashing"), 2500)
  }
}
