import { Controller } from "@hotwired/stimulus"

/**
 * Avatar Preview Controller
 * Handles image preview before upload with drag & drop support
 */
export default class extends Controller {
  static targets = ["input", "display", "preview", "image", "actions", "form"]

  connect() {
    // Setup drag & drop on the form area
    this.element.addEventListener("dragover", this.handleDragOver.bind(this))
    this.element.addEventListener("dragleave", this.handleDragLeave.bind(this))
    this.element.addEventListener("drop", this.handleDrop.bind(this))
  }

  preview(event) {
    const file = event.target.files[0]
    if (file) {
      this.showPreview(file)
    }
  }

  showPreview(file) {
    // Validate file type
    if (!file.type.startsWith("image/")) {
      alert("Per favore seleziona un'immagine valida.")
      return
    }

    // Validate file size (5MB max)
    if (file.size > 5 * 1024 * 1024) {
      alert("L'immagine deve essere inferiore a 5MB.")
      return
    }

    const reader = new FileReader()
    reader.onload = (e) => {
      // Hide current display, show preview
      this.displayTarget.classList.add("hidden")
      this.previewTarget.classList.remove("hidden")
      this.previewTarget.classList.add("flex")
      this.actionsTarget.classList.remove("hidden")
      this.actionsTarget.classList.add("flex")

      // Set preview image
      this.imageTarget.src = e.target.result
    }
    reader.readAsDataURL(file)
  }

  cancel(event) {
    event.preventDefault()

    // Reset file input
    this.inputTarget.value = ""

    // Hide preview, show current display
    this.previewTarget.classList.add("hidden")
    this.previewTarget.classList.remove("flex")
    this.actionsTarget.classList.add("hidden")
    this.actionsTarget.classList.remove("flex")
    this.displayTarget.classList.remove("hidden")
  }

  handleDragOver(event) {
    event.preventDefault()
    event.stopPropagation()
    this.element.classList.add("ring-2", "ring-blue-500", "ring-offset-2")
  }

  handleDragLeave(event) {
    event.preventDefault()
    event.stopPropagation()
    this.element.classList.remove("ring-2", "ring-blue-500", "ring-offset-2")
  }

  handleDrop(event) {
    event.preventDefault()
    event.stopPropagation()
    this.element.classList.remove("ring-2", "ring-blue-500", "ring-offset-2")

    const files = event.dataTransfer.files
    if (files.length > 0) {
      // Set the file to the input
      const dataTransfer = new DataTransfer()
      dataTransfer.items.add(files[0])
      this.inputTarget.files = dataTransfer.files

      // Show preview
      this.showPreview(files[0])
    }
  }
}
