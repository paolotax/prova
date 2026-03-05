import { Controller } from "@hotwired/stimulus"
import { orient } from "helpers/orientation_helpers"

export default class extends Controller {
  static targets = [ "dialog" ]
  static values = {
    modal: { type: Boolean, default: false },
    sizing: { type: Boolean, default: true },
    autoOpen: { type: Boolean, default: false }
  }

  connect() {
    this.dialogTarget.setAttribute("aria-hidden", "true")
    if (this.autoOpenValue) this.open()
  }

  open() {
    const modal = this.modalValue || this.#isTouchDevice

    if (modal) {
      this.#lockBody()
      this.dialogTarget.showModal()
    } else {
      this.dialogTarget.show()
      orient(this.dialogTarget)
    }

    this.loadLazyFrames()
    this.dialogTarget.setAttribute("aria-hidden", "false")
    this.dialogTarget.querySelector("[autofocus]")?.focus({ preventScroll: true })
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
    this.#unlockBody()
    this.dialogTarget.close()
    this.dialogTarget.setAttribute("aria-hidden", "true")
    this.dialogTarget.blur()
    orient(this.dialogTarget, false)
    this.dispatch("close")
  }

  closeOnClickOutside({ target }) {
    if (!this.element.contains(target)) this.close()
  }

  preventCloseOnMorphing(event) {
    if (event.detail?.attributeName === "open") {
      event.preventDefault()
      event.stopPropagation()
    }
  }

  loadLazyFrames() {
    Array.from(this.dialogTarget.querySelectorAll("turbo-frame")).forEach(frame => { frame.loading = "eager" })
  }

  captureKey(event) {
    if (event.key !== "Escape") { event.stopPropagation() }
  }

  #lockBody() {
    this._savedScrollY = window.scrollY
    document.body.style.position = "fixed"
    document.body.style.top = `-${this._savedScrollY}px`
    document.body.style.left = "0"
    document.body.style.right = "0"
  }

  #unlockBody() {
    if (this._savedScrollY == null) return
    document.body.style.position = ""
    document.body.style.top = ""
    document.body.style.left = ""
    document.body.style.right = ""
    window.scrollTo(0, this._savedScrollY)
    this._savedScrollY = null
  }

  get #isTouchDevice() {
    return !window.matchMedia("(any-hover: hover)").matches
  }
}
