import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]

  connect() {
    console.log("ClientableSearchController connected")
    this.timeout = null
    
    // Aggiungiamo l'event listener per l'input
    this.inputTarget.addEventListener("input", () => this.search())
  }

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      const query = this.inputTarget.value
      const type = document.querySelector('select[name="tappable_type"]').value
      
      if (query.length < 2) {
        this.resultsTarget.innerHTML = ""
        return
      }

      fetch(`/searches/clientable?query=${encodeURIComponent(query)}&type=${type}`)
        .then(response => response.text())
        .then(html => {
          this.resultsTarget.innerHTML = html
        })
    }, 300)
  }
} 