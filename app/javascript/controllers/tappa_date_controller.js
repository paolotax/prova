import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["date"]
  static values = {
    giroId: Number,
    date: String
  }

  connect() {
    this.element.addEventListener("dragover", this.handleDragOver.bind(this))
    this.element.addEventListener("drop", this.handleDrop.bind(this))
    this.element.addEventListener("dragleave", this.handleDragLeave.bind(this))
  }

  handleDragOver(e) {
    e.preventDefault()
    e.stopPropagation()
    this.element.classList.add("bg-indigo-50", "border-indigo-500")
  }

  handleDragLeave(e) {
    e.preventDefault()
    e.stopPropagation()
    this.element.classList.remove("bg-indigo-50", "border-indigo-500")
  }

  handleDrop(e) {
    e.preventDefault()
    e.stopPropagation()
    
    this.element.classList.remove("bg-indigo-50", "border-indigo-500")
    
    const schoolId = e.dataTransfer.getData("text/plain")
    const schoolElement = document.querySelector(`[data-school-id="${schoolId}"]`)
    
    if (!schoolElement) return
    
    const tappableType = schoolElement.dataset.tappableType || "ImportScuola"
    const tappaId = schoolElement.dataset.tappaId
    
    // Se l'elemento ha un tappaId, aggiorna la data della tappa esistente
    // altrimenti crea una nuova tappa
    if (tappaId && tappaId !== "null" && tappaId !== "") {
      this.updateTappaDate(tappaId, this.dateValue)
    } else {
      this.createTappa(schoolId, tappableType, this.dateValue)
    }
  }

  async createTappa(schoolId, tappableType, date) {
    try {
      const response = await fetch(`/giri/${this.giroIdValue}/bulk_create_tappe`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({
          tappable_ids: [schoolId],
          data: date,
          giro_id: this.giroIdValue,
          tappable_type: tappableType
        })
      })

      if (response.ok) {
        window.location.reload()
      } else {
        console.error('Errore nella creazione della tappa')
      }
    } catch (error) {
      console.error('Errore nella richiesta:', error)
    }
  }

  async updateTappaDate(tappaId, newDate) {
    try {
      const response = await fetch(`/tappe/${tappaId}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({
          tappa: {
            data_tappa: newDate
          }
        })
      })

      if (response.ok) {
        window.location.reload()
      } else {
        console.error('Errore nell\'aggiornamento della tappa')
      }
    } catch (error) {
      console.error('Errore nella richiesta:', error)
    }
  }
} 