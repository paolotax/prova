import { Controller } from "@hotwired/stimulus"

// Opens PDF form submission in a new tab/window
// Usage: data-controller="pdf-print" on the form
export default class extends Controller {
  submit(event) {
    event.preventDefault()

    const form = this.element
    const url = form.action
    const formData = new FormData(form)

    // Open a new window
    const newWindow = window.open("", "_blank")

    // Create a temporary form in the new window and submit it
    const tempForm = newWindow.document.createElement("form")
    tempForm.method = form.method
    tempForm.action = url

    // Add all form data as hidden inputs
    for (const [name, value] of formData.entries()) {
      const input = newWindow.document.createElement("input")
      input.type = "hidden"
      input.name = name
      input.value = value
      tempForm.appendChild(input)
    }

    // Add CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    if (csrfToken) {
      const csrfInput = newWindow.document.createElement("input")
      csrfInput.type = "hidden"
      csrfInput.name = "authenticity_token"
      csrfInput.value = csrfToken
      tempForm.appendChild(csrfInput)
    }

    newWindow.document.body.appendChild(tempForm)
    tempForm.submit()
  }
}
