import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropZone", "input"]

  dragOver(e) {
    e.preventDefault()
    this.dropZoneTarget.classList.add("bg-gray-100")
  }

  dragEnter(e) {
    e.preventDefault()
    this.dropZoneTarget.classList.add("bg-gray-100")
  }

  dragLeave(e) {
    e.preventDefault()
    this.dropZoneTarget.classList.remove("bg-gray-100")
  }

  drop(e) {
    e.preventDefault()
    this.dropZoneTarget.classList.remove("bg-gray-100")
    
    const files = e.dataTransfer.files
    if (files.length > 0) {
      this.inputTarget.files = files
      this.element.requestSubmit()
    }
  }

  handleFiles(e) {
    if (e.target.files.length > 0) {
      this.element.requestSubmit()
    }
  }
} 