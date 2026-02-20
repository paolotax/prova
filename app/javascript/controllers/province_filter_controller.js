import { Controller } from "@hotwired/stimulus"

// Filtra gli item del combobox comuni in base alle province selezionate.
// Marca gli item con data-province-excluded, poi applica hidden.
// Collabora con il filter controller: entrambi usano hidden, ma
// province-filter segna i suoi con un data attribute separato.
export default class extends Controller {
  update() {
    const selected = [...this.element.querySelectorAll('input[name="province[]"]')].map(i => i.value)
    const form = this.element.closest("form")
    const items = form.querySelectorAll("[data-provincia]")

    items.forEach(item => {
      const excluded = selected.length > 0 && !selected.includes(item.dataset.provincia)
      item.toggleAttribute("data-province-excluded", excluded)
      item.toggleAttribute("hidden", excluded)
    })
  }
}
