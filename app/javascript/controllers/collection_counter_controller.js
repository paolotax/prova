import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["count"]
  static values = { 
    total: Number,
    modelName: String 
  }
  
  connect() {
    console.log("Collection counter controller connected")
    
    // Inizializza i valori dal contenuto del target
    if (this.hasCountTarget) {
      const text = this.countTarget.textContent.trim()
      const match = text.match(/^(\d+)\s+(.+)$/)
      
      if (match) {
        this.totalValue = parseInt(match[1], 10)
        this.modelNameValue = match[2]
      }
    }
    
    // Ascolta l'evento personalizzato per decrementare
    document.addEventListener("collection-counter:decrement", this.handleDecrement.bind(this))
  }
  
  disconnect() {
    // Rimuovi l'event listener quando il controller viene disconnesso
    document.removeEventListener("collection-counter:decrement", this.handleDecrement.bind(this))
  }
  
  handleDecrement(event) {
    const amount = event.detail?.amount || 1
    this.totalValue = Math.max(0, this.totalValue - amount)
    this.updateDisplay()
  }
  
  // Incrementa il contatore di un valore specifico
  increment(event) {
    const amount = event.detail?.amount || 1
    this.totalValue = this.totalValue + amount
    this.updateDisplay()
  }
  
  // Aggiorna il contatore con un valore specifico
  update(event) {
    if (event.detail?.count !== undefined) {
      this.totalValue = event.detail.count
    }
    
    if (event.detail?.modelName) {
      this.modelNameValue = event.detail.modelName
    }
    
    this.updateDisplay()
  }
  
  // Aggiorna il display con i valori correnti
  updateDisplay() {
    if (this.hasCountTarget) {
      this.countTarget.textContent = `${this.totalValue} ${this.modelNameValue}`
    }
  }
  
  // Callback quando il valore totale cambia
  totalValueChanged() {
    this.updateDisplay()
  }
} 