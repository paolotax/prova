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
    "viewContent",
    "editContent",
    "tableWrapper",
    "editControls",
    "dialogTitle",
    "libroCombobox",
    "quantitaField",
    "prezzoField",
    "scontoField",
    "isbnDisplay"
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

    console.log('documento-editor connected, righeValue:', this.righeValue)

    // Se già in editing mode (es. da server), attiva subito
    if (this.editingValue) {
      this.activateEditingUI()
    }
  }

  // Called automatically when righeValue changes
  righeValueChanged(newValue, oldValue) {
    console.log('righeValueChanged:', { newValue, oldValue })
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

    // Show edit content, hide view content
    if (this.hasEditContentTarget) this.editContentTarget.hidden = false
    if (this.hasViewContentTarget) this.viewContentTarget.hidden = true

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

    // Show view content, hide edit content
    if (this.hasViewContentTarget) this.viewContentTarget.hidden = false
    if (this.hasEditContentTarget) this.editContentTarget.hidden = true

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
          <strong>${quantita}</strong>
        </td>
        <td class="documento-table__cell documento-table__cell--right documento-table__cell--hidden-mobile">
          <span class="documento-table__subtitle">${this.formatCurrency(prezzo)}</span>
        </td>
        <td class="documento-table__cell documento-table__cell--right documento-table__cell--hidden-mobile">
          <span class="documento-table__subtitle">${sconto > 0 ? `${sconto}%` : ''}</span>
        </td>
        <td class="documento-table__cell documento-table__cell--right documento-table__cell--hidden-mobile">
          <span class="documento-table__subtitle">${this.formatCurrency(importo)}</span>
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
          <strong>${quantita}</strong>
        </td>
        <td class="documento-table__cell documento-table__cell--right documento-table__cell--hidden-mobile">
          <span class="documento-table__subtitle">${this.formatCurrency(prezzo)}</span>
        </td>
        <td class="documento-table__cell documento-table__cell--right documento-table__cell--hidden-mobile">
          <span class="documento-table__subtitle">${sconto > 0 ? `${sconto}%` : ''}</span>
        </td>
        <td class="documento-table__cell documento-table__cell--right documento-table__cell--hidden-mobile">
          <span class="documento-table__subtitle">${this.formatCurrency(importo)}</span>
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

    // Populate dialog title
    if (this.hasDialogTitleTarget) {
      this.dialogTitleTarget.textContent = isEdit ? 'Modifica riga' : 'Nuova riga'
    }

    // Set form fields
    if (this.hasQuantitaFieldTarget) this.quantitaFieldTarget.value = riga.quantita || 1
    if (this.hasPrezzoFieldTarget) this.prezzoFieldTarget.value = (riga.prezzo_cents || 0) / 100
    if (this.hasScontoFieldTarget) this.scontoFieldTarget.value = riga.sconto || 0

    // Set combobox value (libro)
    if (this.hasLibroComboboxTarget) {
      // libroComboboxTarget is the hw-combobox element or an element inside it
      const comboboxEl = this.libroComboboxTarget
      const hwCombobox = comboboxEl.tagName === 'HW-COMBOBOX'
        ? comboboxEl
        : comboboxEl.closest('hw-combobox') || comboboxEl.querySelector('hw-combobox')

      // Find inputs - try multiple selectors
      const hiddenInput = hwCombobox?.querySelector('input[type="hidden"]') ||
                          dialog.querySelector('input[name="riga[libro_id]"]')
      const textInput = hwCombobox?.querySelector('input[type="text"]') ||
                        comboboxEl.querySelector('input[type="text"]')
      const listbox = hwCombobox?.querySelector('.hw-combobox__listbox')

      // Clear listbox before setting new values
      if (listbox) listbox.innerHTML = ''

      if (hiddenInput) {
        hiddenInput.value = riga.libro_id || ''
      }
      if (textInput) {
        textInput.value = riga.titolo || riga.libro?.titolo || ''
      }

      // Close the listbox if open
      if (hwCombobox?.close) hwCombobox.close()

      // Set lastLibroId on tax-combobox-libro to avoid unnecessary fetches
      const taxComboboxEl = dialog.querySelector('[data-controller*="tax-combobox-libro"]')
      if (taxComboboxEl && riga.libro_id) {
        taxComboboxEl.dataset.taxComboboxLibroLastLibroIdValue = String(riga.libro_id)
      }
    }

    // Store current libro data for display (includes ISBN)
    const isbn = riga.codice_isbn || riga.libro?.codice_isbn || ''
    this._currentLibro = {
      id: riga.libro_id,
      titolo: riga.titolo || riga.libro?.titolo || '',
      codice_isbn: isbn
    }

    // Show ISBN in dialog
    if (this.hasIsbnDisplayTarget) {
      this.isbnDisplayTarget.textContent = isbn ? `ISBN: ${isbn}` : ''
    }

    dialog.showModal()

    // Autofocus sulla combobox dopo che il dialog è aperto
    setTimeout(() => {
      if (this.hasLibroComboboxTarget) {
        const input = this.libroComboboxTarget.querySelector('input[type="text"]')
        if (input) {
          input.focus()
          input.select()
        }
      }
    }, 50)
  }

  /**
   * Focus next field on Enter
   */
  focusNextField(event) {
    event.preventDefault()
    const current = event.target
    const fields = [this.quantitaFieldTarget, this.prezzoFieldTarget, this.scontoFieldTarget]
    const currentIndex = fields.indexOf(current)
    if (currentIndex < fields.length - 1) {
      fields[currentIndex + 1].focus()
      fields[currentIndex + 1].select()
    }
  }

  /**
   * Submit dialog on Enter from last field
   */
  submitDialog(event) {
    event.preventDefault()
    const form = this.rigaDialogTarget.querySelector('form')
    if (form) form.requestSubmit()
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
    this._selectedLibro = null
    this._currentLibro = null

    // Clear combobox values and listbox when dialog closes
    if (this.hasRigaDialogTarget && this.hasLibroComboboxTarget) {
      const comboboxEl = this.libroComboboxTarget
      const hwCombobox = comboboxEl.tagName === 'HW-COMBOBOX'
        ? comboboxEl
        : comboboxEl.closest('hw-combobox') || comboboxEl.querySelector('hw-combobox')

      const hiddenInput = hwCombobox?.querySelector('input[type="hidden"]')
      const textInput = hwCombobox?.querySelector('input[type="text"]')
      const listbox = hwCombobox?.querySelector('.hw-combobox__listbox')

      if (hiddenInput) hiddenInput.value = ''
      if (textInput) textInput.value = ''
      if (listbox) listbox.innerHTML = ''

      // Reset lastLibroId on tax-combobox-libro
      const taxComboboxEl = this.rigaDialogTarget.querySelector('[data-controller*="tax-combobox-libro"]')
      if (taxComboboxEl) {
        taxComboboxEl.dataset.taxComboboxLibroLastLibroIdValue = ''
      }
    }

    // Clear ISBN display
    if (this.hasIsbnDisplayTarget) {
      this.isbnDisplayTarget.textContent = ''
    }

    this.element.focus()
  }

  /**
   * Called when riga dialog form is submitted
   */
  saveRigaFromDialog(event) {
    console.log('=== saveRigaFromDialog CALLED ===')
    event.preventDefault()
    event.stopPropagation()

    // Get libro_id from combobox - the hidden input created by hotwire-combobox
    // It's the sibling hidden input next to the text input in the hw-combobox structure
    let libroId = null
    if (this.hasLibroComboboxTarget) {
      // hotwire-combobox creates: hw-combobox > input[type=hidden] + input[type=text]
      const hwCombobox = this.libroComboboxTarget.closest('hw-combobox')
      if (hwCombobox) {
        const hiddenInput = hwCombobox.querySelector('input[type="hidden"]')
        console.log('Found hw-combobox hidden input:', hiddenInput, 'value:', hiddenInput?.value)
        libroId = hiddenInput?.value ? parseInt(hiddenInput.value, 10) : null
      }
      // Fallback to looking for input by name
      if (!libroId) {
        const byName = this.rigaDialogTarget.querySelector('input[name="riga[libro_id]"]')
        console.log('Fallback input by name:', byName, 'value:', byName?.value)
        libroId = byName?.value ? parseInt(byName.value, 10) : null
      }
    }

    console.log('quantitaFieldTarget:', this.quantitaFieldTarget)
    console.log('quantitaFieldTarget.value:', this.quantitaFieldTarget?.value)
    console.log('prezzoFieldTarget:', this.prezzoFieldTarget)
    console.log('prezzoFieldTarget.value:', this.prezzoFieldTarget?.value)

    const quantita = this.hasQuantitaFieldTarget ? parseInt(this.quantitaFieldTarget.value, 10) || 1 : 1
    const prezzo = this.hasPrezzoFieldTarget ? parseFloat(this.prezzoFieldTarget.value) || 0 : 0
    const sconto = this.hasScontoFieldTarget ? parseFloat(this.scontoFieldTarget.value) || 0 : 0

    console.log('Form values:', { libroId, quantita, prezzo, sconto })

    // Get libro data from selection or current edit data
    const libroData = this._selectedLibro || this._currentLibro || {}
    console.log('libroData:', libroData)

    // Validate libro selection
    if (!libroId) {
      alert('Seleziona un libro')
      return
    }

    const rigaData = {
      libro_id: libroId,
      libro: { id: libroId, titolo: libroData.titolo || '', codice_isbn: libroData.codice_isbn || '' },
      titolo: libroData.titolo || '',
      codice_isbn: libroData.codice_isbn || '',
      quantita: quantita,
      prezzo_cents: Math.round(prezzo * 100),
      sconto: sconto
    }

    console.log('rigaData to save:', rigaData)
    console.log('editingRigaIndex:', this.editingRigaIndex)
    console.log('current righeValue:', JSON.stringify(this.righeValue))

    if (this.editingRigaIndex !== null) {
      // Find the actual index in righeValue (accounting for _destroy)
      // IMPORTANT: Get righeValue once to avoid Stimulus returning different array copies
      const allRighe = this.righeValue
      let visibleIndex = 0
      let actualIndex = -1

      for (let i = 0; i < allRighe.length; i++) {
        if (!allRighe[i]._destroy) {
          if (visibleIndex === this.editingRigaIndex) {
            actualIndex = i
            break
          }
          visibleIndex++
        }
      }

      console.log('Updating riga at actualIndex:', actualIndex, 'editingRigaIndex:', this.editingRigaIndex)
      if (actualIndex !== -1) {
        this.updateRiga(actualIndex, rigaData)
      }
    } else {
      console.log('Adding new riga')
      this.addRiga(rigaData)
    }

    console.log('righeValue after save:', JSON.stringify(this.righeValue))

    // Determine which row to select after closing
    let indexToSelect
    if (this.editingRigaIndex !== null) {
      // Edited existing row - select same row
      indexToSelect = this.editingRigaIndex
    } else {
      // Added new row - select last visible row
      const visibleRighe = this.righeValue.filter(r => !r._destroy)
      indexToSelect = visibleRighe.length - 1
    }

    this.closeDialog()
    this._selectedLibro = null

    // Select the row after a short delay to let the DOM update
    setTimeout(() => {
      if (indexToSelect >= 0) {
        this.setCurrentIndex(indexToSelect)
      }
    }, 50)
  }

  /**
   * Called when libro is selected in combobox
   */
  onLibroSelected(event) {
    console.log('onLibroSelected event:', event)
    console.log('onLibroSelected event.detail:', event.detail)

    // hotwire-combobox passa value e display in event.detail
    const value = event.detail?.value
    const display = event.detail?.display

    // If cleared, reset
    if (!value) {
      this._selectedLibro = null
      return
    }

    const libroId = parseInt(value, 10)

    // If same libro as current, keep the existing ISBN from _currentLibro
    if (this._currentLibro && String(this._currentLibro.id) === String(libroId)) {
      this._selectedLibro = {
        id: libroId,
        titolo: display || this._currentLibro.titolo || '',
        codice_isbn: this._currentLibro.codice_isbn || ''
      }
    } else {
      // New libro - ISBN will come from libro:loaded event
      this._selectedLibro = {
        id: libroId,
        titolo: display || '',
        codice_isbn: '' // Will be updated by onLibroLoaded
      }
    }

    console.log('_selectedLibro set to:', this._selectedLibro)
  }

  /**
   * Called when libro data is loaded from server (via tax-combobox-libro)
   * This provides the ISBN and other details
   */
  onLibroLoaded(event) {
    console.log('onLibroLoaded event:', event.detail)

    const data = event.detail
    if (!data?.id) return

    const isbn = data.codice_isbn || ''

    // Update _selectedLibro with full data including ISBN
    this._selectedLibro = {
      id: parseInt(data.id, 10),
      titolo: data.titolo || this._selectedLibro?.titolo || '',
      codice_isbn: isbn
    }

    // Show ISBN in dialog
    if (this.hasIsbnDisplayTarget) {
      this.isbnDisplayTarget.textContent = isbn ? `ISBN: ${isbn}` : ''
    }

    console.log('_selectedLibro updated with ISBN:', this._selectedLibro)
  }

  deleteRow(event) {
    event?.preventDefault()
    const visibleIndex = parseInt(event.currentTarget.dataset.rigaIndex, 10)
    if (isNaN(visibleIndex)) return

    if (confirm('Eliminare questa riga?')) {
      const actualIndex = this.findActualIndex(visibleIndex)
      if (actualIndex !== -1) {
        this.removeRiga(actualIndex)
      }
    }
  }

  deleteCurrentRow(event) {
    event?.preventDefault()
    if (this.currentIndex < 0) return

    if (confirm('Eliminare questa riga?')) {
      const actualIndex = this.findActualIndex(this.currentIndex)
      if (actualIndex !== -1) {
        this.removeRiga(actualIndex)
      }
    }
  }

  // Helper: find actual index in righeValue from visible index
  findActualIndex(visibleIndex) {
    const allRighe = this.righeValue
    let currentVisible = 0

    for (let i = 0; i < allRighe.length; i++) {
      if (!allRighe[i]._destroy) {
        if (currentVisible === visibleIndex) {
          return i
        }
        currentVisible++
      }
    }
    return -1
  }

  // ==================== SAVE / CANCEL ====================

  /**
   * Save documento + righe via form submission.
   * Populates hidden fields for righe nested attributes,
   * then submits the form (POST for new, PATCH for existing).
   */
  save(event) {
    event?.preventDefault()

    this.populateHiddenFields()

    if (this.hasFormTarget) {
      this.formTarget.requestSubmit()
    }
  }

  /**
   * Populate hidden fields with righe as nested attributes
   * for the documento form. Only sends new, modified, or destroyed righe.
   */
  populateHiddenFields() {
    if (!this.hasHiddenFieldsTarget) return

    const container = this.hiddenFieldsTarget
    container.innerHTML = ''

    let index = 0
    this.righeValue.forEach(riga => {
      const prefix = `documento[documento_righe_attributes][${index}]`

      if (riga._isNew) {
        // New riga
        this._addHiddenField(container, `${prefix}[riga_attributes][libro_id]`, riga.libro_id)
        this._addHiddenField(container, `${prefix}[riga_attributes][quantita]`, riga.quantita || 1)
        this._addHiddenField(container, `${prefix}[riga_attributes][prezzo_cents]`, riga.prezzo_cents || 0)
        this._addHiddenField(container, `${prefix}[riga_attributes][sconto]`, riga.sconto || 0)
        index++
      } else if (riga._destroy) {
        // Existing riga marked for deletion
        this._addHiddenField(container, `${prefix}[id]`, riga.documento_riga_id)
        this._addHiddenField(container, `${prefix}[_destroy]`, '1')
        index++
      } else if (riga._modified) {
        // Existing riga modified
        this._addHiddenField(container, `${prefix}[id]`, riga.documento_riga_id)
        this._addHiddenField(container, `${prefix}[riga_attributes][id]`, riga.riga_id)
        this._addHiddenField(container, `${prefix}[riga_attributes][libro_id]`, riga.libro_id)
        this._addHiddenField(container, `${prefix}[riga_attributes][quantita]`, riga.quantita || 1)
        this._addHiddenField(container, `${prefix}[riga_attributes][prezzo_cents]`, riga.prezzo_cents || 0)
        this._addHiddenField(container, `${prefix}[riga_attributes][sconto]`, riga.sconto || 0)
        index++
      }
      // Unchanged righe: skip — Rails leaves them untouched
    })
  }

  _addHiddenField(container, name, value) {
    const input = document.createElement('input')
    input.type = 'hidden'
    input.name = name
    input.value = value ?? ''
    container.appendChild(input)
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
