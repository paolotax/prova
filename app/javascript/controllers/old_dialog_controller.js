// tutorial https://github.com/corsego/151-dialog-turbo-modals/blob/main/app/controllers/comments_controller.rb

// app/javascript/controllers/dialog_controller.js
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dialog"
export default class extends Controller {
  
  connect() {
    this.open()
    // needed because ESC key does not trigger close event
    this.element.addEventListener("close", this.enableBodyScroll.bind(this))
    // Dismiss native date pickers when clicking outside the input
    this.dismissPicker = this.dismissPicker.bind(this)
    this.element.addEventListener("mousedown", this.dismissPicker)
  }

  disconnect() {
    this.element.removeEventListener("close", this.enableBodyScroll.bind(this))
    this.element.removeEventListener("mousedown", this.dismissPicker)
  }

  dismissPicker(event) {
    const active = document.activeElement
    if (active && active.type === "date" && active !== event.target) {
      active.blur()
    }
  }

  // hide modal on successful form submission
  // data-action="turbo:submit-end->turbo-modal#submitEnd"
  submitEnd(e) {
    if (e.detail.success) {
      this.close()
    }
  }

  open() {
    this.element.showModal()
    document.body.classList.add('overflow-hidden')
  }

  close() {
    // Blur active element to dismiss native date pickers
    document.activeElement?.blur()
    this.element.close()
    // clean up modal content
    const frame = document.getElementById('modal')
    frame.removeAttribute("src")
    frame.innerHTML = ""
  }

  enableBodyScroll() {
    const frame = document.getElementById('modal')
    frame.removeAttribute("src")
    frame.innerHTML = ""
    document.body.classList.remove('overflow-hidden')
  }

  clickOutside(event) {
    if (event.target === this.element) {
      this.close()
    }
  }
}