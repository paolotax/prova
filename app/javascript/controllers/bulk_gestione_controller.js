import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame"]

  loadContent() {
    const checkboxes = document.querySelectorAll('input[type="checkbox"][name="ids[]"]:checked')
    const ids = Array.from(checkboxes).map(cb => cb.value)

    if (ids.length === 0) return

    const params = new URLSearchParams()
    ids.forEach(id => params.append("ids[]", id))

    // Get account_id from current URL path
    const pathParts = window.location.pathname.split("/")
    const accountId = pathParts[1]

    const url = `/${accountId}/documenti/bulk_gestione?${params.toString()}`

    if (this.hasFrameTarget) {
      this.frameTarget.src = url
    }
  }
}
