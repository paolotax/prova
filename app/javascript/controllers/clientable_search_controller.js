import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "select"]

  connect() {
    this.search()
  }

  updateType() {
    this.inputTarget.value = ""
    this.search()
  }

  async search() {
    const query = this.inputTarget.value
    const type = this.selectTarget.value
    const giroId = document.querySelector('#tappe-form select[name="giro_id"]').value
    
    const response = await fetch(`/searches/clientable?type=${type}&query=${query}&giro_id=${giroId}`)
    const html = await response.text()
    
    this.resultsTarget.innerHTML = html
    
    // Aggiorna il contatore usando getElementById
    const counter = document.getElementById('results-counter')
    const count = this.resultsTarget.querySelectorAll('input[type="checkbox"]').length
    const label = type === 'ImportScuola' ? 'scuole' : 'clienti'
    counter.textContent = `${count} ${label} trovati`
  }
} 