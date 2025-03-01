import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list"]
  static values = { 
    counterId: String,
    itemSelector: String,
    initialCount: { type: Number, default: -1 }  // Valore iniziale del contatore
  }
  
  connect() {
    console.log("List observer controller connected")
    
    // Configura l'observer per monitorare i cambiamenti nella lista
    this.observer = new MutationObserver(this.handleMutations.bind(this))
    
    // Inizia a osservare la lista per aggiunte/rimozioni di nodi
    this.observer.observe(this.listTarget, {
      childList: true,
      subtree: false  // Osserva solo i figli diretti
    })
    
    // Inizializza il valore del contatore se non è già stato impostato
    if (this.initialCountValue === -1) {
      this.initializeCounter()
    }
  }
  
  disconnect() {
    // Ferma l'observer quando il controller viene disconnesso
    if (this.observer) {
      this.observer.disconnect()
    }
  }
  
  initializeCounter() {
    const counterElement = document.getElementById(this.counterIdValue)
    if (counterElement) {
      const controller = this.application.getControllerForElementAndIdentifier(
        counterElement,
        'collection-counter'
      )
      
      if (controller && controller.totalValue) {
        // Salva il valore iniziale del contatore
        this.initialCountValue = controller.totalValue
        console.log(`Valore iniziale del contatore: ${this.initialCountValue}`)
      }
    }
  }
  
  handleMutations(mutations) {
    let addedCount = 0
    let removedCount = 0
    
    mutations.forEach(mutation => {
      // Conta solo i nodi che corrispondono al selettore
      const selector = this.itemSelectorValue || "*"
      
      // Conta gli elementi aggiunti
      Array.from(mutation.addedNodes).forEach(node => {
        if (node.nodeType === Node.ELEMENT_NODE) {
          if (!selector || node.matches(selector)) {
            addedCount++
          }
        }
      })
      
      // Conta gli elementi rimossi
      Array.from(mutation.removedNodes).forEach(node => {
        if (node.nodeType === Node.ELEMENT_NODE) {
          if (!selector || node.matches(selector)) {
            removedCount++
          }
        }
      })
    })
    
    // Aggiorna il contatore solo se ci sono state modifiche
    if (addedCount > 0 || removedCount > 0) {
      console.log(`Elementi aggiunti: ${addedCount}, rimossi: ${removedCount}`)
      this.updateCounter(addedCount - removedCount)
    }
  }
  
  updateCounter(delta) {
    if (this.initialCountValue === -1) {
      this.initializeCounter()
      return
    }
    
    const counterElement = document.getElementById(this.counterIdValue)
    if (counterElement) {
      const controller = this.application.getControllerForElementAndIdentifier(
        counterElement,
        'collection-counter'
      )
      
      if (controller) {
        // Aggiorna il valore del contatore in base al delta
        controller.totalValue += delta
        console.log(`Contatore aggiornato a: ${controller.totalValue}`)
      }
    }
  }
} 