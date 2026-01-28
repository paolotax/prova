import { Controller } from "@hotwired/stimulus"

/**
 * DocumentoEditorController - Transactional editing for documenti
 *
 * Manages client-side state for documento and righe.
 * Changes are kept in memory until "Salva" is clicked.
 * "Annulla" discards all unsaved changes.
 *
 * Keyboard navigation (when editing):
 * - Arrow Up/Down: Navigate between rows
 * - Enter: Open edit dialog for selected row
 * - Insert: Open new riga dialog
 * - Delete: Delete selected row
 * - Escape: Close dialog
 */
export default class extends Controller {
  static targets = [
    "righeContainer",
    "rigaDialog",
    "form",
    "hiddenFields",
    "item",
    "totaleImporto",
    "totaleCopie",
    "viewFooter",
    "editFooter",
    "tableWrapper",
    "editControls"
  ]

  static values = {
    documento: Object,
    righe: Array,
    isNew: Boolean,
    editing: Boolean,
    libriPath: String,
    documentoPath: String,
    documentiPath: String
  }

  connect() {
    this.currentIndex = -1
    this.nextTempId = Date.now()
    this._originalRighe = JSON.parse(JSON.stringify(this.righeValue))

    // Se già in editing mode (es. da server), attiva subito
    if (this.editingValue) {
      this.activateEditingUI()
    }
  }

  disconnect() {
    this.currentIndex = -1
  }

  // ==================== EDIT MODE TOGGLE ====================

  /**
   * Enter editing mode (called by "Modifica" button)
   */
  enterEditMode(event) {
    event?.preventDefault()
    this.editingValue = true
    this._originalRighe = JSON.parse(JSON.stringify(this.righeValue))
    this.activateEditingUI()
  }

  /**
   * Exit editing mode without saving
   */
  exitEditMode(event) {
    event?.preventDefault()

    if (this.isDirty && !confirm('Ci sono modifiche non salvate. Vuoi davvero annullare?')) {
      return
    }

    // Restore original data
    this.righeValue = JSON.parse(JSON.stringify(this._originalRighe))
    this.editingValue = false
    this.isDirty = false
    this.deactivateEditingUI()
  }

  /**
   * Activate editing UI elements
   */
  activateEditingUI() {
    this.element.classList.add('documento-editor--editing')

    // Show edit footer, hide view footer
    if (this.hasViewFooterTarget) this.viewFooterTarget.hidden = true
    if (this.hasEditFooterTarget) this.editFooterTarget.hidden = false

    // Show edit controls (+ Nuova riga button)
    if (this.hasEditControlsTarget) this.editControlsTarget.hidden = false

    // Enable table navigation
    if (this.hasTableWrapperTarget) {
      this.tableWrapperTarget.classList.add('documento-table--editing')
    }

    // Render righe with edit controls
    this.renderRighe()
    this.updateTotals()

    // Focus the table for keyboard navigation
    this.element.focus()

    // Seleziona automaticamente il primo item
    if (this.itemTargets.length > 0) {
      this.setCurrentIndex(0)
    }
  }

  /**
   * Deactivate editing UI elements
   */
  deactivateEditingUI() {
    this.element.classList.remove('documento-editor--editing')
    this.element.classList.remove('documento-editor--dirty')

    // Show view footer, hide edit footer
    if (this.hasViewFooterTarget) this.viewFooterTarget.hidden = false
    if (this.hasEditFooterTarget) this.editFooterTarget.hidden = true

    // Hide edit controls
    if (this.hasEditControlsTarget) this.editControlsTarget.hidden = true

    // Disable table navigation
    if (this.hasTableWrapperTarget) {
      this.tableWrapperTarget.classList.remove('documento-table--editing')
    }

    // Re-render righe without edit controls
    this.renderRigheReadonly()
  }

  // ==================== RIGHE OPERATIONS (IN MEMORY) ====================

  /**
   * Add a new riga to memory (not DB)
   */
  addRiga(rigaData) {
    const newRiga = {
      ...rigaData,
      _tempId: this.nextTempId++,
      _isNew: true
    }
    this.righeValue = [...this.righeValue, newRiga]
    this.renderRighe()
    this.updateTotals()
    this.markDirty()
  }

  /**
   * Update an existing riga in memory
   */
  updateRiga(index, rigaData) {
    const righe = [...this.righeValue]
    righe[index] = { ...righe[index], ...rigaData, _modified: true }
    this.righeValue = righe
    this.renderRighe()
    this.updateTotals()
    this.markDirty()
  }

  /**
   * Remove a riga from memory
   * - For new (unsaved) righe: remove completely
   * - For existing righe: mark with _destroy: true
   */
  removeRiga(index) {
    const righe = [...this.righeValue]
    const riga = righe[index]

    if (riga._isNew) {
      // New riga not yet in DB, just remove it
      righe.splice(index, 1)
    } else {
      // Existing riga, mark for deletion
      righe[index] = { ...riga, _destroy: true }
    }

    this.righeValue = righe
    this.renderRighe()
    this.updateTotals()
    this.markDirty()

    // Adjust current index after removal
    if (this.currentIndex >= righe.filter(r => !r._destroy).length) {
      this.currentIndex = Math.max(0, righe.filter(r => !r._destroy).length - 1)
    }
  }

  // ==================== RENDERING ====================

  /**
   * Render the righe table from current state (editing mode)
   */
  renderRighe() {
    if (!this.hasRigheContainerTarget) return
    if (!this.editingValue) return  // Non renderizzare se non in editing

    const visibleRighe = this.righeValue.filter(r => !r._destroy)

    if (visibleRighe.length === 0) {
      this.righeContainerTarget.innerHTML = `
        <tr>
          <td colspan="7" class="documento-table__empty">
            Nessuna riga. Premi "+ Nuova riga" o Insert per aggiungere.
          </td>
        </tr>
      `
      return
    }

    const html = visibleRighe.map((riga, visibleIndex) => this.renderRigaRow(riga, visibleIndex)).join('')
    this.righeContainerTarget.innerHTML = html
  }

  /**
   * Render a single riga row
   */
  renderRigaRow(riga, index) {
    const prezzo = (riga.prezzo_cents || 0) / 100
    const sconto = riga.sconto || 0
    const quantita = riga.quantita || 1
    const prezzoScontato = prezzo - (prezzo * sconto / 100)
    const importo = prezzoScontato * quantita

    const rowId = riga.id ? `documento_riga_${riga.id}` : `temp_riga_${riga._tempId}`
    const titolo = riga.libro?.titolo || riga.titolo || 'Libro non specificato'
    const isbn = riga.libro?.codice_isbn || riga.codice_isbn || ''
    const isModified = riga._isNew || riga._modified ? 'documento-table__row--modified' : ''

    return `
      <tr id="${rowId}"
          class="documento-table__row ${isModified}"
          data-documento-editor-target="item"
          data-riga-index="${index}"
          data-action="click->documento-editor#selectRow dblclick->documento-editor#openEditDialog"
          tabindex="-1">
        <td class="documento-table__cell documento-table__cell--title">
          <span class="documento-table__title">${this.escapeHtml(titolo)}</span>
          <div class="documento-table__values">
            <span class="documento-table__value-isbn">${this.escapeHtml(isbn)}</span>
            <span class="documento-table__value"><strong>${quantita}</strong> cp</span>
            <span class="documento-table__value">${this.formatCurrency(prezzo)}</span>
            ${sconto > 0 ? `<span class="documento-table__value">-${sconto}%</span>` : ''}
            <span class="documento-table__value"><strong>${this.formatCurrency(importo)}</strong></span>
          </div>
        </td>
        <td class="documento-table__cell documento-table__cell--right documento-table__cell--hidden-mobile">
          <span class="documento-table__subtitle">${this.escapeHtml(isbn)}</span>
        </td>
        <td class="documento-table__cell documento-table__cell--right documento-table__cell--hidden-mobile">
          ${this.formatCurrency(prezzo)}
        </td>
        <td class="documento-table__cell documento-table__cell--right documento-table__cell--hidden-mobile">
          ${quantita}
        </td>
        <td class="documento-table__cell documento-table__cell--right documento-table__cell--hidden-mobile">
          ${sconto > 0 ? `${sconto}%` : ''}
        </td>
        <td class="documento-table__cell documento-table__cell--right documento-table__cell--hidden-mobile">
          ${this.formatCurrency(importo)}
        </td>
        <td class="documento-table__cell documento-table__cell--right documento-table__actions">
          <div class="flex gap-quarter align-center">
            <button type="button"
                    class="btn btn--small borderless"
                    data-action="documento-editor#openEditDialogForRow"
                    data-riga-index="${index}"
                    title="Modifica">
              <kbd class="kbd">&#9166;</kbd>
            </button>
            <button type="button"
                    class="btn btn--small borderless txt-negative"
                    data-action="documento-editor#deleteRow"
                    data-riga-index="${index}"
                    title="Elimina">
              <kbd class="kbd">Canc</kbd>
            </button>
          </div>
        </td>
      </tr>
    `
  }

  /**
   * Render righe in readonly mode (no edit controls)
   */
  renderRigheReadonly() {
    if (!this.hasRigheContainerTarget) return

    const visibleRighe = this.righeValue.filter(r => !r._destroy)

    if (visibleRighe.length === 0) {
      this.righeContainerTarget.innerHTML = `
        <tr>
          <td colspan="6" class="documento-table__empty">Nessuna riga</td>
        </tr>
      `
      return
    }

    const html = visibleRighe.map((riga, index) => this.renderRigaRowReadonly(riga)).join('')
    this.righeContainerTarget.innerHTML = html
  }

  /**
   * Render a single riga row in readonly mode
   */
  renderRigaRowReadonly(riga) {
    const prezzo = (riga.prezzo_cents || 0) / 100
    const sconto = riga.sconto || 0
    const quantita = riga.quantita || 1
    const prezzoScontato = prezzo - (prezzo * sconto / 100)
    const importo = prezzoScontato * quantita

    const titolo = riga.libro?.titolo || riga.titolo || 'Libro non specificato'
    const isbn = riga.libro?.codice_isbn || riga.codice_isbn || ''

    return `
      <tr class="documento-table__row">
        <td class="documento-table__cell documento-table__cell--title">
          <span class="documento-table__title">${this.escapeHtml(titolo)}</span>
          <div class="documento-table__values">
            <span class="documento-table__value-isbn">${this.escapeHtml(isbn)}</span>
            <span class="documento-table__value"><strong>${quantita}</strong> cp</span>
            <span class="documento-table__value">${this.formatCurrency(prezzo)}</span>
            ${sconto > 0 ? `<span class="documento-table__value">-${sconto}%</span>` : ''}
            <span class="documento-table__value"><strong>${this.formatCurrency(importo)}</strong></span>
          </div>
        </td>
        <td class="documento-table__cell documento-table__cell--right documento-table__cell--hidden-mobile">
          <span class="documento-table__subtitle">${this.escapeHtml(isbn)}</span>
        </td>
        <td class="documento-table__cell documento-table__cell--right documento-table__cell--hidden-mobile">
          ${this.formatCurrency(prezzo)}
        </td>
        <td class="documento-table__cell documento-table__cell--right documento-table__cell--hidden-mobile">
          ${quantita}
        </td>
        <td class="documento-table__cell documento-table__cell--right documento-table__cell--hidden-mobile">
          ${sconto > 0 ? `${sconto}%` : ''}
        </td>
        <td class="documento-table__cell documento-table__cell--right documento-table__cell--hidden-mobile">
          ${this.formatCurrency(importo)}
        </td>
      </tr>
    `
  }

  /**
   * Update totals display
   */
  updateTotals() {
    const visibleRighe = this.righeValue.filter(r => !r._destroy)

    let totalImporto = 0
    let totalCopie = 0

    visibleRighe.forEach(riga => {
      const prezzo = (riga.prezzo_cents || 0) / 100
      const sconto = riga.sconto || 0
      const quantita = riga.quantita || 1
      const prezzoScontato = prezzo - (prezzo * sconto / 100)
      totalImporto += prezzoScontato * quantita
      totalCopie += quantita
    })

    if (this.hasTotaleImportoTarget) {
      this.totaleImportoTarget.textContent = this.formatCurrency(totalImporto)
    }
    if (this.hasTotaleCopieTarget) {
      this.totaleCopieTarget.textContent = totalCopie
    }
  }

  // ==================== KEYBOARD NAVIGATION ====================

  navigate(event) {
    // Solo in editing mode
    if (!this.editingValue) return
    if (this.shouldIgnoreKeyboard(event)) return

    const handlers = {
      ArrowDown: () => this.selectNext(event),
      ArrowUp: () => this.selectPrevious(event),
      Enter: () => this.openEditDialog(event),
      Insert: () => this.openNewDialog(event),
      Delete: () => this.deleteCurrentRow(event),
      Escape: () => this.closeDialog(event)
    }

    const handler = handlers[event.key]
    if (handler) {
      handler()
    }
  }

  selectRow(event) {
    // Don't select if clicking on a link or button
    if (event.target.closest('a') || event.target.closest('button')) return

    const row = event.currentTarget
    const index = parseInt(row.dataset.rigaIndex, 10)

    if (!isNaN(index)) {
      this.setCurrentIndex(index)
      this.element.focus()
    }
  }

  selectNext(event) {
    event.preventDefault()
    const visibleRighe = this.righeValue.filter(r => !r._destroy)

    if (this.currentIndex < 0 && visibleRighe.length > 0) {
      this.setCurrentIndex(0)
    } else {
      const nextIndex = Math.min(this.currentIndex + 1, visibleRighe.length - 1)
      this.setCurrentIndex(nextIndex)
    }
  }

  selectPrevious(event) {
    event.preventDefault()
    const visibleRighe = this.righeValue.filter(r => !r._destroy)

    if (this.currentIndex < 0 && visibleRighe.length > 0) {
      this.setCurrentIndex(visibleRighe.length - 1)
    } else {
      const prevIndex = Math.max(this.currentIndex - 1, 0)
      this.setCurrentIndex(prevIndex)
    }
  }

  setCurrentIndex(index) {
    // Remove selection from all items
    this.itemTargets.forEach(item => {
      item.removeAttribute("aria-selected")
      item.classList.remove("documento-table__row--selected")
    })

    this.currentIndex = index

    // Set selection on current item
    const item = this.itemTargets[index]
    if (item) {
      item.setAttribute("aria-selected", "true")
      item.classList.add("documento-table__row--selected")
      item.scrollIntoView({ block: "nearest", behavior: "smooth" })
    }
  }

  get currentRiga() {
    const visibleRighe = this.righeValue.filter(r => !r._destroy)
    return visibleRighe[this.currentIndex]
  }

  // ==================== DIALOG OPERATIONS ====================

  openNewDialog(event) {
    event?.preventDefault()
    if (!this.hasRigaDialogTarget) return

    this.editingRigaIndex = null
    this.showRigaDialog({
      libro_id: null,
      titolo: '',
      codice_isbn: '',
      quantita: 1,
      prezzo_cents: 0,
      sconto: 0
    })
  }

  openEditDialog(event) {
    event?.preventDefault()
    if (!this.hasRigaDialogTarget) return
    if (this.currentIndex < 0) return

    this.editingRigaIndex = this.currentIndex
    const riga = this.currentRiga
    if (riga) {
      this.showRigaDialog(riga)
    }
  }

  openEditDialogForRow(event) {
    event?.preventDefault()
    const index = parseInt(event.currentTarget.dataset.rigaIndex, 10)
    if (isNaN(index)) return

    const visibleRighe = this.righeValue.filter(r => !r._destroy)
    const riga = visibleRighe[index]
    if (!riga) return

    this.editingRigaIndex = index
    this.showRigaDialog(riga)
  }

  showRigaDialog(riga) {
    const dialog = this.rigaDialogTarget
    const isEdit = this.editingRigaIndex !== null

    // Populate dialog fields
    const titleEl = dialog.querySelector('[data-dialog-title]')
    if (titleEl) {
      titleEl.textContent = isEdit ? 'Modifica riga' : 'Nuova riga'
    }

    // Set form fields
    const libroIdField = dialog.querySelector('[data-field="libro_id"]')
    const quantitaField = dialog.querySelector('[data-field="quantita"]')
    const prezzoField = dialog.querySelector('[data-field="prezzo"]')
    const scontoField = dialog.querySelector('[data-field="sconto"]')

    if (libroIdField) libroIdField.value = riga.libro_id || ''
    if (quantitaField) quantitaField.value = riga.quantita || 1
    if (prezzoField) prezzoField.value = (riga.prezzo_cents || 0) / 100
    if (scontoField) scontoField.value = riga.sconto || 0

    // Store current libro data for display
    this._currentLibro = riga.libro || { id: riga.libro_id, titolo: riga.titolo, codice_isbn: riga.codice_isbn }

    dialog.showModal()
  }

  closeDialog(event) {
    event?.preventDefault()
    if (this.hasRigaDialogTarget && this.rigaDialogTarget.open) {
      this.rigaDialogTarget.close()
      this.editingRigaIndex = null
      this.element.focus()
    }
  }

  dialogClosed() {
    this.editingRigaIndex = null
    this.element.focus()
  }

  /**
   * Called when riga dialog form is submitted
   */
  saveRigaFromDialog(event) {
    event.preventDefault()
    const dialog = this.rigaDialogTarget

    const libroIdField = dialog.querySelector('[data-field="libro_id"]')
    const quantitaField = dialog.querySelector('[data-field="quantita"]')
    const prezzoField = dialog.querySelector('[data-field="prezzo"]')
    const scontoField = dialog.querySelector('[data-field="sconto"]')

    const libroId = libroIdField ? parseInt(libroIdField.value, 10) : null
    const quantita = quantitaField ? parseInt(quantitaField.value, 10) || 1 : 1
    const prezzo = prezzoField ? parseFloat(prezzoField.value) || 0 : 0
    const sconto = scontoField ? parseFloat(scontoField.value) || 0 : 0

    // Get libro data from combobox display (if available)
    const libroData = this._selectedLibro || this._currentLibro || {}

    const rigaData = {
      libro_id: libroId,
      libro: { id: libroId, titolo: libroData.titolo || '', codice_isbn: libroData.codice_isbn || '' },
      titolo: libroData.titolo || '',
      codice_isbn: libroData.codice_isbn || '',
      quantita: quantita,
      prezzo_cents: Math.round(prezzo * 100),
      sconto: sconto
    }

    if (this.editingRigaIndex !== null) {
      // Find the actual index in righeValue (accounting for _destroy)
      const visibleRighe = this.righeValue.filter(r => !r._destroy)
      const editedRiga = visibleRighe[this.editingRigaIndex]
      const actualIndex = this.righeValue.indexOf(editedRiga)
      if (actualIndex !== -1) {
        this.updateRiga(actualIndex, rigaData)
      }
    } else {
      this.addRiga(rigaData)
    }

    this.closeDialog()
    this._selectedLibro = null
  }

  /**
   * Called when libro is selected in combobox
   */
  onLibroSelected(event) {
    const { value, display } = event.detail || {}

    // Parse the libro data from the combobox
    // The display usually contains the title
    this._selectedLibro = {
      id: value ? parseInt(value, 10) : null,
      titolo: display || '',
      codice_isbn: ''  // Will be filled if available
    }

    // Try to get prezzo from the selection if available
    if (event.detail?.dataset?.prezzo) {
      const prezzoField = this.rigaDialogTarget?.querySelector('[data-field="prezzo"]')
      if (prezzoField) {
        prezzoField.value = event.detail.dataset.prezzo
      }
    }
  }

  deleteRow(event) {
    event?.preventDefault()
    const index = parseInt(event.currentTarget.dataset.rigaIndex, 10)
    if (isNaN(index)) return

    if (confirm('Eliminare questa riga?')) {
      // Find actual index in righeValue
      const visibleRighe = this.righeValue.filter(r => !r._destroy)
      const riga = visibleRighe[index]
      const actualIndex = this.righeValue.indexOf(riga)
      if (actualIndex !== -1) {
        this.removeRiga(actualIndex)
      }
    }
  }

  deleteCurrentRow(event) {
    event?.preventDefault()
    if (this.currentIndex < 0) return

    if (confirm('Eliminare questa riga?')) {
      const visibleRighe = this.righeValue.filter(r => !r._destroy)
      const riga = visibleRighe[this.currentIndex]
      const actualIndex = this.righeValue.indexOf(riga)
      if (actualIndex !== -1) {
        this.removeRiga(actualIndex)
      }
    }
  }

  // ==================== SAVE / CANCEL ====================

  /**
   * Save all changes to the server
   */
  save(event) {
    event?.preventDefault()

    // Build hidden fields for nested attributes
    this.buildHiddenFields()

    // Submit the form
    if (this.hasFormTarget) {
      this.formTarget.requestSubmit()
    }
  }

  /**
   * Build hidden fields for documento_righe_attributes
   */
  buildHiddenFields() {
    if (!this.hasHiddenFieldsTarget) return

    let html = ''

    this.righeValue.forEach((riga, index) => {
      const prefix = `documento[documento_righe_attributes][${index}]`

      // documento_riga id (if existing)
      if (riga.documento_riga_id) {
        html += `<input type="hidden" name="${prefix}[id]" value="${riga.documento_riga_id}">`
      }

      // _destroy flag
      if (riga._destroy) {
        html += `<input type="hidden" name="${prefix}[_destroy]" value="1">`
      }

      // riga_attributes
      const rigaPrefix = `${prefix}[riga_attributes]`

      // riga id (if existing)
      if (riga.riga_id) {
        html += `<input type="hidden" name="${rigaPrefix}[id]" value="${riga.riga_id}">`
      }

      html += `<input type="hidden" name="${rigaPrefix}[libro_id]" value="${riga.libro_id || ''}">`
      html += `<input type="hidden" name="${rigaPrefix}[quantita]" value="${riga.quantita || 1}">`
      html += `<input type="hidden" name="${rigaPrefix}[prezzo_cents]" value="${riga.prezzo_cents || 0}">`
      html += `<input type="hidden" name="${rigaPrefix}[sconto]" value="${riga.sconto || 0}">`
    })

    this.hiddenFieldsTarget.innerHTML = html
  }

  /**
   * Cancel editing, discard all changes
   */
  cancel(event) {
    event?.preventDefault()

    if (this.isNewValue) {
      // New document, go back to list
      if (this.isDirty && !confirm('Ci sono modifiche non salvate. Vuoi davvero annullare?')) {
        return
      }
      window.location.href = this.documentiPathValue || '/documenti'
    } else {
      // Existing document, exit editing mode
      this.exitEditMode(event)
    }
  }

  // ==================== DIRTY STATE ====================

  markDirty() {
    this.isDirty = true
    this.element.classList.add('documento-editor--dirty')
  }

  // ==================== UTILITIES ====================

  formatCurrency(value) {
    return new Intl.NumberFormat('it-IT', {
      style: 'currency',
      currency: 'EUR'
    }).format(value)
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text || ''
    return div.innerHTML
  }

  shouldIgnoreKeyboard(event) {
    const tagName = event.target.tagName.toLowerCase()
    const isInput = ["input", "textarea", "select"].includes(tagName)
    const isContentEditable = event.target.isContentEditable
    const dialogOpen = this.hasRigaDialogTarget && this.rigaDialogTarget.open

    // Allow Escape to close dialog even when typing
    if (event.key === "Escape" && dialogOpen) return false

    return isInput || isContentEditable || dialogOpen
  }
}
