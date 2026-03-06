import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame"]
  static values = { url: String }

  loadContent() {
    const checkboxes = document.querySelectorAll('input[type="checkbox"][name="ids[]"]:checked')
    const ids = Array.from(checkboxes).map(cb => cb.value)

    if (ids.length === 0) return

    const params = new URLSearchParams()
    ids.forEach(id => params.append("ids[]", id))

    const pathParts = window.location.pathname.split("/")
    const accountId = pathParts[1]

    const basePath = this.urlValue || `/${accountId}/documenti/bulk_gestione`
    const url = `${basePath}?${params.toString()}`

    if (this.hasFrameTarget) {
      this.frameTarget.src = url
    }
  }
}
