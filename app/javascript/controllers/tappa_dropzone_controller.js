import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["date", "dropzone", "form"]
  static values = {
    giroId: Number
  }

  connect() {
    this.dropzoneTarget.addEventListener("dragover", this.handleDragOver.bind(this))
    this.dropzoneTarget.addEventListener("drop", this.handleDrop.bind(this))
    this.droppedSchools = new Set()
  }

  handleDragStart(e) {
    e.dataTransfer.setData("text/plain", e.target.dataset.schoolId)
    e.target.classList.add("opacity-50")
    this.dropzoneTarget.classList.add("border-green-500")
  }

  handleDragEnd(e) {
    e.target.classList.remove("opacity-50")
    this.dropzoneTarget.classList.remove("border-green-500")
  }

  handleDragOver(e) {
    e.preventDefault()
    e.stopPropagation()
    this.dropzoneTarget.classList.add("bg-green-50")
  }

  handleDrop(e) {
    e.preventDefault()
    e.stopPropagation()
    
    this.dropzoneTarget.classList.remove("bg-green-50")
    this.dropzoneTarget.classList.remove("border-green-500")
    
    const schoolId = e.dataTransfer.getData("text/plain")
    const schoolElement = document.querySelector(`[data-school-id="${schoolId}"]`)
    
    if (!schoolElement || this.droppedSchools.has(schoolId)) return
    
    // Clona il badge e aggiungilo alla dropzone
    const clonedBadge = schoolElement.cloneNode(true)
    
    // Mantieni solo le classi che vogliamo
    const classesToKeep = Array.from(schoolElement.classList).filter(cls => 
      cls.startsWith('bg-') || 
      cls.startsWith('text-') || 
      ['rounded-full', 'text-xs', 'font-medium', 'px-2.5', 'py-0.5', 'inline-flex', 'items-center', 'gap-1'].includes(cls)
    )
    clonedBadge.className = classesToKeep.join(' ')
    
    // Rimuovi gli attributi di drag and drop dal clone
    clonedBadge.removeAttribute("draggable")
    clonedBadge.removeAttribute("data-action")
    
    // Rimuovi il pulsante × se presente
    const existingRemoveButton = clonedBadge.querySelector('form')
    if (existingRemoveButton) existingRemoveButton.remove()
    
    // Aggiungi il pulsante di rimozione
    const removeButton = document.createElement("button")
    removeButton.innerHTML = "×"
    removeButton.classList.add("ml-1", "font-bold", "hover:text-red-500")
    removeButton.onclick = () => this.removeSchool(schoolId, clonedBadge)
    clonedBadge.appendChild(removeButton)
    
    // Aggiungi l'input hidden per il form
    const hiddenInput = document.createElement("input")
    hiddenInput.type = "hidden"
    hiddenInput.name = "tappable_ids[]"
    hiddenInput.value = schoolId
    this.formTarget.appendChild(hiddenInput)
    
    // Se è il primo elemento, rimuovi il testo placeholder
    if (this.dropzoneTarget.querySelector("p")) {
      this.dropzoneTarget.querySelector("p").remove()
    }
    
    this.dropzoneTarget.appendChild(clonedBadge)
    this.droppedSchools.add(schoolId)
    
    // Nascondi l'elemento originale
    schoolElement.style.display = "none"
  }

  removeSchool(schoolId, badge) {
    // Rimuovi il badge dalla dropzone
    badge.remove()
    
    // Rimuovi l'input hidden
    this.formTarget.querySelector(`input[value="${schoolId}"]`).remove()
    
    // Mostra nuovamente l'elemento originale
    const originalBadge = document.querySelector(`[data-school-id="${schoolId}"]`)
    originalBadge.style.display = ""
    
    this.droppedSchools.delete(schoolId)
    
    // Se non ci sono più badge, mostra il testo placeholder
    if (this.droppedSchools.size === 0) {
      const placeholder = document.createElement("p")
      placeholder.classList.add("text-center", "text-gray-500")
      placeholder.textContent = "Trascina qui le scuole da programmare"
      this.dropzoneTarget.appendChild(placeholder)
    }
  }

  dragLeave(e) {
    e.preventDefault()
    this.dropzoneTarget.classList.remove("bg-green-50")
  }
} 