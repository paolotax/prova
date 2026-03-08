import { Controller } from "@hotwired/stimulus"

// Switches disciplina field between free text and guided select
// based on classe + categoria, using prezzi ministeriali data.
// Only activates for "scolastico" categories (ministeriali, scolastico, etc.)
//
export default class extends Controller {
  static targets = ["classe", "disciplina", "categoria"]
  static values = { options: Object }

  connect() {
    this.#update()
  }

  classeChanged() {
    this.#update()
  }

  categoriaChanged() {
    this.#update()
  }

  #update() {
    const classe = this.classeTarget.value
    const isScolastico = this.#isScolastico()
    const disciplines = isScolastico ? this.optionsValue[classe] : null

    if (disciplines && disciplines.length > 0) {
      this.#switchToSelect(disciplines)
    } else {
      this.#switchToText()
    }
  }

  #isScolastico() {
    if (!this.hasCategoriaTarget) return true

    const select = this.categoriaTarget
    const text = select.options[select.selectedIndex]?.text?.toLowerCase() || ""
    return /ministerial|scolastic/.test(text)
  }

  #switchToSelect(disciplines) {
    const current = this.disciplinaTarget
    if (current.tagName === "SELECT") {
      this.#populateSelect(current, disciplines)
      return
    }

    const select = document.createElement("select")
    select.name = current.name
    select.id = current.id
    select.className = current.className.replace("input", "input input--select")
    select.dataset.disciplinaSelectTarget = "disciplina"

    this.#populateSelect(select, disciplines, current.value)
    current.replaceWith(select)
  }

  #switchToText() {
    const current = this.disciplinaTarget
    if (current.tagName === "INPUT") return

    const input = document.createElement("input")
    input.type = "text"
    input.name = current.name
    input.id = current.id
    input.className = "input"
    input.value = current.value
    input.dataset.disciplinaSelectTarget = "disciplina"

    current.replaceWith(input)
  }

  #populateSelect(select, disciplines, currentValue = null) {
    const value = currentValue ?? select.value
    select.innerHTML = ""

    const blank = document.createElement("option")
    blank.value = ""
    blank.textContent = "Seleziona disciplina..."
    select.appendChild(blank)

    disciplines.forEach(d => {
      const option = document.createElement("option")
      option.value = d
      option.textContent = d
      if (d === value) option.selected = true
      select.appendChild(option)
    })
  }
}
