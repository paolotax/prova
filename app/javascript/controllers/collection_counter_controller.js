import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["count"]
  static values = { 
    total: Number,
    modelName: String 
  }
          
  // Aggiorna il display con i valori correnti
  updateDisplay() {
    if (this.hasCountTarget) {
      this.countTarget.textContent = `${this.totalValue} ${this.modelNameValue}`
    }
  }
  
  // Callback quando il valore totale cambia
  totalValueChanged() {
    console.log(`Valore totale cambiato: ${this.totalValue}`)
    this.updateDisplay()
  }
} 