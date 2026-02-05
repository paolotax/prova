import { Controller } from "@hotwired/stimulus"

// Typeable date field with dd/mm/yyyy display format.
// Uses a hidden native date picker for calendar access (opened via button),
// and a hidden input with ISO format for form submission.
export default class extends Controller {
  static targets = ["display", "picker", "hidden"]

  connect() {
    if (this.hasHiddenTarget && this.hiddenTarget.value) {
      this.displayTarget.value = this.isoToDisplay(this.hiddenTarget.value)
    }
  }

  openPicker() {
    if (this.hasPickerTarget) {
      this.pickerTarget.showPicker()
    }
  }

  pickerChanged() {
    const iso = this.pickerTarget.value
    if (iso) {
      this.hiddenTarget.value = iso
      this.displayTarget.value = this.isoToDisplay(iso)
    }
  }

  parseText() {
    const iso = this.displayToIso(this.displayTarget.value.trim())
    if (iso) {
      this.hiddenTarget.value = iso
      if (this.hasPickerTarget) this.pickerTarget.value = iso
    }
  }

  formatOnBlur() {
    const text = this.displayTarget.value.trim()
    if (!text) {
      this.hiddenTarget.value = ""
      return
    }
    const iso = this.displayToIso(text)
    if (iso) {
      this.displayTarget.value = this.isoToDisplay(iso)
      this.hiddenTarget.value = iso
    }
  }

  // dd/mm/yyyy or d/m/yyyy -> yyyy-mm-dd
  displayToIso(text) {
    const match = text.match(/^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})$/)
    if (!match) return null
    const dd = match[1].padStart(2, "0")
    const mm = match[2].padStart(2, "0")
    const yyyy = match[3]
    const d = parseInt(dd), m = parseInt(mm)
    if (d < 1 || d > 31 || m < 1 || m > 12) return null
    return `${yyyy}-${mm}-${dd}`
  }

  // yyyy-mm-dd -> dd/mm/yyyy
  isoToDisplay(iso) {
    const parts = iso.split("-")
    if (parts.length !== 3) return iso
    return `${parts[2]}/${parts[1]}/${parts[0]}`
  }
}
