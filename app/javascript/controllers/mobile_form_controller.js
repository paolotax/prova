import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "fileInput", "previews", "submit"]

  fileInputTargetConnected() {
    this.fileInputTarget.addEventListener("change", () => this.previewFiles())
  }

  previewFiles() {
    this.previewsTarget.innerHTML = ""
    const files = this.fileInputTarget.files

    for (const file of files) {
      const wrapper = document.createElement("div")
      wrapper.classList.add("flex", "align-center", "gap-quarter")

      if (file.type.startsWith("image/")) {
        const img = document.createElement("img")
        img.src = URL.createObjectURL(file)
        img.onload = () => URL.revokeObjectURL(img.src)
        img.style.cssText = "width: 60px; height: 60px; object-fit: cover; border-radius: var(--radius-small);"
        wrapper.appendChild(img)
      } else {
        const label = document.createElement("span")
        label.classList.add("txt-small")
        label.textContent = file.name
        wrapper.appendChild(label)
      }

      this.previewsTarget.appendChild(wrapper)
    }
  }
}
