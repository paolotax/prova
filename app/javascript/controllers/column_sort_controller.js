import { Controller } from "@hotwired/stimulus"

// Sort colonne della vista tabella (header .data-table__head).
// Click: ciclo asc → desc → nessun sort (sostituisce le altre colonne).
// Shift+click: aggiunge/cicla la colonna in coda mantenendo le altre
// (multi-sort). Il param sort vive solo nell'URL: naviga nel frame
// search_results con advance, così back/condivisione funzionano.
export default class extends Controller {
  static values = { frame: { type: String, default: "search_results" } }

  toggle(event) {
    const key = event.params.key
    if (!key) return

    const url = new URL(window.location.href)
    const entries = this.#parse(url.searchParams.get("sort"))
    const current = entries.find(entry => entry.key === key)

    if (event.shiftKey) {
      if (!current) {
        entries.push({ key, direction: "asc" })
      } else if (current.direction === "asc") {
        current.direction = "desc"
      } else {
        entries.splice(entries.indexOf(current), 1)
      }
    } else {
      if (entries.length === 1 && current?.direction === "asc") {
        entries.splice(0, entries.length, { key, direction: "desc" })
      } else if (entries.length === 1 && current?.direction === "desc") {
        entries.length = 0
      } else {
        entries.splice(0, entries.length, { key, direction: "asc" })
      }
    }

    const sortParam = entries.map(entry => `${entry.key}.${entry.direction}`).join(",")
    if (sortParam) {
      url.searchParams.set("sort", sortParam)
    } else {
      url.searchParams.delete("sort")
    }
    url.searchParams.delete("page")

    this.#visit(url)
  }

  #parse(param) {
    return (param || "").split(",").filter(Boolean).map(part => {
      const [key, direction] = part.split(".")
      return { key, direction }
    })
  }

  #visit(url) {
    const link = document.createElement("a")
    link.href = url.toString()
    link.dataset.turboFrame = this.frameValue
    link.dataset.turboAction = "advance"
    link.hidden = true
    document.body.appendChild(link)
    link.click()
    link.remove()
  }
}
