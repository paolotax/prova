import { Controller } from "@hotwired/stimulus"

// Keyboard navigation for documento righe table
// - Arrow Up/Down: Navigate between rows
// - Enter: Open edit dialog for selected row
// - Insert: Open new riga dialog
// - Delete: Delete selected row (with confirmation)
// - Escape: Close dialog

export default class extends Controller {
  static targets = ["item", "dialog", "frame"]
  static values = {
    newRigaPath: String,
    documentoId: String
  }

  connect() {
    this.currentIndex = -1
    console.log("righe-table controller connected", {
      items: this.itemTargets.length,
      hasDialog: this.hasDialogTarget,
      hasFrame: this.hasFrameTarget,
      itemTargets: this.itemTargets
    })

    // Debug: mostra quali elementi sono stati trovati come target
    this.itemTargets.forEach((item, i) => {
      console.log(`  item[${i}]:`, item.id, item.dataset.editPath)
    })
  }

  disconnect() {
    this.currentIndex = -1
  }

  navigate(event) {
    console.log("navigate key:", event.key, "shouldIgnore:", this.#shouldIgnoreKeyboard(event))

    if (this.#shouldIgnoreKeyboard(event)) return

    const handlers = {
      ArrowDown: () => this.selectNext(event),
      ArrowUp: () => this.selectPrevious(event),
      Enter: () => this.openEdit(event),
      Insert: () => this.openNew(event),
      Delete: () => this.deleteCurrentRow(event),
      Escape: () => this.closeDialog(event)
    }

    const handler = handlers[event.key]
    if (handler) {
      console.log("handling key:", event.key)
      handler()
    }
  }

  // Row selection
  select(event) {
    console.log(">>> select() ENTRY", event.target, event.currentTarget)

    // Non selezionare se il click è su un link o button
    const clickedElement = event.target
    if (clickedElement.closest('a') || clickedElement.closest('button')) {
      console.log("Click on link/button, skipping select")
      return
    }

    const row = event.currentTarget
    const index = this.itemTargets.indexOf(row)
    console.log("select() processing", { row, index, itemTargets: this.itemTargets.length })

    if (index !== -1) {
      this.#setCurrentIndex(index)
      // Assicura che il container abbia il focus per ricevere i keydown
      this.element.focus()
      console.log("Row selected, index:", index)
    } else {
      console.log("Row not found in itemTargets!")
    }
  }

  selectNext(event) {
    event.preventDefault()
    // Se nulla è selezionato, parti dal primo
    if (this.currentIndex < 0 && this.itemTargets.length > 0) {
      this.#setCurrentIndex(0)
    } else {
      const nextIndex = Math.min(this.currentIndex + 1, this.itemTargets.length - 1)
      this.#setCurrentIndex(nextIndex)
    }
  }

  selectPrevious(event) {
    event.preventDefault()
    // Se nulla è selezionato, parti dall'ultimo
    if (this.currentIndex < 0 && this.itemTargets.length > 0) {
      this.#setCurrentIndex(this.itemTargets.length - 1)
    } else {
      const prevIndex = Math.max(this.currentIndex - 1, 0)
      this.#setCurrentIndex(prevIndex)
    }
  }

  // Dialog operations
  openEdit(event) {
    event?.preventDefault()

    console.log("openEdit called", {
      currentItem: this.currentItem,
      currentIndex: this.currentIndex,
      hasFrame: this.hasFrameTarget,
      hasDialog: this.hasDialogTarget
    })

    if (!this.currentItem) {
      console.log("No current item selected")
      return
    }

    const editPath = this.currentItem.dataset.editPath
    console.log("editPath:", editPath)

    if (editPath && this.hasFrameTarget && this.hasDialogTarget) {
      // Apri il dialog prima così il frame è visibile
      this.dialogTarget.showModal()
      // Imposta src per caricare il contenuto
      this.frameTarget.src = editPath
    }
  }

  openNew(event) {
    event?.preventDefault()

    console.log("openNew called", {
      newRigaPath: this.newRigaPathValue,
      hasFrame: this.hasFrameTarget,
      hasDialog: this.hasDialogTarget
    })

    if (this.hasFrameTarget && this.hasDialogTarget && this.newRigaPathValue) {
      // Apri il dialog prima così il frame è visibile
      this.dialogTarget.showModal()
      // Imposta src per caricare il contenuto
      this.frameTarget.src = this.newRigaPathValue
    }
  }

  closeDialog(event) {
    if (this.hasDialogTarget && this.dialogTarget.open) {
      event?.preventDefault()
      this.dialogTarget.close()
      this.element.focus()
    }
  }

  // Called when dialog closes to refresh focus
  dialogClosed() {
    this.element.focus()
  }

  // Called after successful form submission
  formSubmitted() {
    this.closeDialog()
  }

  deleteCurrentRow(event) {
    if (!this.currentItem) return

    event?.preventDefault()

    // Find and click the delete button in the current row
    const deleteButton = this.currentItem.querySelector('[data-righe-table-delete]')
    if (deleteButton) {
      deleteButton.click()
    }
  }

  // Private helpers
  get currentItem() {
    if (this.currentIndex >= 0 && this.currentIndex < this.itemTargets.length) {
      return this.itemTargets[this.currentIndex]
    }
    return null
  }

  #setCurrentIndex(index) {
    // Remove selection from all items
    this.itemTargets.forEach(item => {
      item.removeAttribute("aria-selected")
      item.classList.remove("documento-table__row--selected")
    })

    this.currentIndex = index

    // Set selection on current item
    const item = this.currentItem
    if (item) {
      item.setAttribute("aria-selected", "true")
      item.classList.add("documento-table__row--selected")
      item.scrollIntoView({ block: "nearest", behavior: "smooth" })
    }
  }

  #shouldIgnoreKeyboard(event) {
    // Ignore if typing in an input or if dialog is open
    const tagName = event.target.tagName.toLowerCase()
    const isInput = ["input", "textarea", "select"].includes(tagName)
    const isContentEditable = event.target.isContentEditable
    const dialogOpen = this.hasDialogTarget && this.dialogTarget.open

    // Allow Escape to close dialog even when typing
    if (event.key === "Escape" && dialogOpen) return false

    return isInput || isContentEditable || dialogOpen
  }
}
