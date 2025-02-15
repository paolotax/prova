import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["date", "dropzone", "form", "schoolList"]
  static values = {
    giroId: Number
  }

  connect() {
    this.dropzoneTarget.addEventListener("dragover", this.handleDragOver.bind(this))
    this.dropzoneTarget.addEventListener("drop", this.handleDrop.bind(this))
    this.droppedSchools = new Set()
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
    
    const schoolId = e.dataTransfer.getData("text/plain")
    const schoolElement = document.querySelector(`[data-school-id="${schoolId}"]`)
    
    if (!schoolElement || this.droppedSchools.has(schoolId)) return
    
    // Clona il badge e aggiungilo alla dropzone
    const clonedBadge = schoolElement.cloneNode(true)
    clonedBadge.classList.remove("hover:opacity-75")
    clonedBadge.classList.add("cursor-pointer")
    clonedBadge.removeAttribute("href")
    
    // Aggiungi il pulsante di rimozione
    const removeButton = document.createElement("span")
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
  }

  dragLeave() {
    this.dropzoneTarget.classList.remove("bg-green-50")
  }
} 