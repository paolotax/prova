import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="cattedra-matcher"
export default class extends Controller {
  static targets = ["item", "canvas", "status"]
  static values = {
    createUrl: String,
    deleteUrl: String,
    tipoScuola: String
  }

  connect() {
    this.selected = null
    this.lines = []
    this.boundRedrawLines = this.redrawLines.bind(this)
    this.drawExistingMappings()
    window.addEventListener("resize", this.boundRedrawLines)
  }

  disconnect() {
    window.removeEventListener("resize", this.boundRedrawLines)
  }

  redrawLines() {
    while (this.canvasTarget.firstChild) {
      this.canvasTarget.firstChild.remove()
    }
    this.lines.forEach(info => {
      const el1 = this.element.querySelector(`[data-item-id="${info.cattedra}"][data-side="cattedra"]`)
      const el2 = this.element.querySelector(`[data-item-id="${info.disciplina}"][data-side="disciplina"]`)
      if (el1 && el2) {
        info.element = this.drawSvgLine(el1, el2, info.cattedra, info.disciplina)
      }
    })
  }

  drawExistingMappings() {
    // Read pre-existing mappings from data attributes on the container
    const mappingsEl = this.element.querySelector("[data-mappings]")
    if (!mappingsEl) return

    const mappings = JSON.parse(mappingsEl.dataset.mappings || "[]")
    mappings.forEach(m => {
      const el1 = this.element.querySelector(`[data-item-id="${m.cattedra}"][data-side="cattedra"]`)
      const el2 = this.element.querySelector(`[data-item-id="${m.disciplina}"][data-side="disciplina"]`)
      if (el1 && el2) {
        const line = this.drawSvgLine(el1, el2, m.cattedra, m.disciplina)
        this.lines.push({ cattedra: m.cattedra, disciplina: m.disciplina, element: line })
        el1.classList.add("matched")
        el2.classList.add("matched")
      }
    })
  }

  select(event) {
    const clicked = event.currentTarget
    const side = clicked.dataset.side
    const itemId = clicked.dataset.itemId

    // If nothing selected, select this one
    if (!this.selected) {
      this.selected = clicked
      clicked.classList.add("selected")
      return
    }

    // If clicking same item, deselect
    if (this.selected === clicked) {
      this.selected.classList.remove("selected")
      this.selected = null
      return
    }

    // If same side, switch selection
    if (this.selected.dataset.side === side) {
      this.selected.classList.remove("selected")
      this.selected = clicked
      clicked.classList.add("selected")
      return
    }

    // Different sides: create or remove mapping
    const cattedraEl = side === "cattedra" ? clicked : this.selected
    const disciplinaEl = side === "disciplina" ? clicked : this.selected
    const cattedra = cattedraEl.dataset.itemId
    const disciplina = disciplinaEl.dataset.itemId

    // Check if mapping already exists → remove it
    const existingIdx = this.lines.findIndex(
      l => l.cattedra === cattedra && l.disciplina === disciplina
    )

    if (existingIdx >= 0) {
      this.removeMapping(existingIdx, cattedraEl, disciplinaEl, cattedra, disciplina)
    } else {
      this.createMapping(cattedraEl, disciplinaEl, cattedra, disciplina)
    }

    this.selected.classList.remove("selected")
    this.selected = null
  }

  createMapping(cattedraEl, disciplinaEl, cattedra, disciplina) {
    const line = this.drawSvgLine(cattedraEl, disciplinaEl, cattedra, disciplina)
    this.lines.push({ cattedra, disciplina, element: line })
    cattedraEl.classList.add("matched")
    disciplinaEl.classList.add("matched")

    // Persist
    fetch(this.createUrlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
      },
      body: JSON.stringify({ cattedra, disciplina, tipo_scuola: this.tipoScuolaValue })
    })

    this.updateStatus()
  }

  removeMapping(idx, cattedraEl, disciplinaEl, cattedra, disciplina) {
    const info = this.lines[idx]
    info.element.remove()
    this.lines.splice(idx, 1)

    // Update matched class
    if (!this.lines.some(l => l.cattedra === cattedra)) {
      cattedraEl.classList.remove("matched")
    }
    if (!this.lines.some(l => l.disciplina === disciplina)) {
      disciplinaEl.classList.remove("matched")
    }

    // Persist deletion
    fetch(this.deleteUrlValue, {
      method: "DELETE",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
      },
      body: JSON.stringify({ cattedra, disciplina, tipo_scuola: this.tipoScuolaValue })
    })

    this.updateStatus()
  }

  clickLine(event) {
    const group = event.currentTarget
    const cattedra = group.dataset.cattedra
    const disciplina = group.dataset.disciplina

    const idx = this.lines.findIndex(
      l => l.cattedra === cattedra && l.disciplina === disciplina
    )
    if (idx < 0) return

    const cattedraEl = this.element.querySelector(`[data-item-id="${cattedra}"][data-side="cattedra"]`)
    const disciplinaEl = this.element.querySelector(`[data-item-id="${disciplina}"][data-side="disciplina"]`)

    if (cattedraEl && disciplinaEl) {
      this.removeMapping(idx, cattedraEl, disciplinaEl, cattedra, disciplina)
    }
  }

  drawSvgLine(el1, el2, cattedra, disciplina) {
    const rect1 = el1.getBoundingClientRect()
    const rect2 = el2.getBoundingClientRect()
    const canvasRect = this.canvasTarget.getBoundingClientRect()

    const x1 = rect1.right - canvasRect.left
    const y1 = rect1.top + rect1.height / 2 - canvasRect.top
    const x2 = rect2.left - canvasRect.left
    const y2 = rect2.top + rect2.height / 2 - canvasRect.top

    const group = document.createElementNS("http://www.w3.org/2000/svg", "g")
    group.dataset.cattedra = cattedra
    group.dataset.disciplina = disciplina
    group.style.cursor = "pointer"
    group.style.pointerEvents = "auto"
    group.addEventListener("click", this.clickLine.bind(this))

    // Hit area (invisible thick line)
    const hitArea = document.createElementNS("http://www.w3.org/2000/svg", "line")
    hitArea.setAttribute("x1", x1)
    hitArea.setAttribute("y1", y1)
    hitArea.setAttribute("x2", x2)
    hitArea.setAttribute("y2", y2)
    hitArea.style.stroke = "transparent"
    hitArea.style.strokeWidth = "12"
    group.appendChild(hitArea)

    // Visible line
    const line = document.createElementNS("http://www.w3.org/2000/svg", "line")
    line.setAttribute("x1", x1)
    line.setAttribute("y1", y1)
    line.setAttribute("x2", x2)
    line.setAttribute("y2", y2)
    line.style.stroke = "var(--color-accent, #3b82f6)"
    line.style.strokeWidth = "2"
    line.style.strokeLinecap = "round"
    group.appendChild(line)

    this.canvasTarget.appendChild(group)
    return group
  }

  updateStatus() {
    if (!this.hasStatusTarget) return
    const unmatchedCattedre = this.itemTargets.filter(
      el => el.dataset.side === "cattedra" && !el.classList.contains("matched")
    ).length
    const unmatchedDiscipline = this.itemTargets.filter(
      el => el.dataset.side === "disciplina" && !el.classList.contains("matched")
    ).length

    if (unmatchedCattedre === 0 && unmatchedDiscipline === 0) {
      this.statusTarget.textContent = `Tutte collegate (${this.lines.length} collegamenti)`
    } else {
      const parts = []
      if (unmatchedCattedre > 0) parts.push(`${unmatchedCattedre} cattedre`)
      if (unmatchedDiscipline > 0) parts.push(`${unmatchedDiscipline} discipline`)
      this.statusTarget.textContent = `${parts.join(", ")} da collegare`
    }
  }
}
