import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "pdf-viewer"

  connect() {
    super.connect()
    // const element = this.bridgeElement
    // const url = element.bridgeAttribute("url")
    // this.send("connect", { url })
  }
    
  // Aggiungi un target per il link
  static targets = ["link"]

  // Gestisci il click sul link
  onClick(event) {
    event.preventDefault()
    const url = this.element.getAttribute("data-bridge-url")

    // Aggiungi i headers necessari
    const headers = {
      // Esempio con token CSRF
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content,
      // Se stai usando un token di autenticazione
      'Authorization': 'Bearer ' + this.getAuthToken()
    }

    this.send("connect", { url, headers })
  }

  getAuthToken() {
    // Implementa la logica per ottenere il token di autenticazione
    // Questo è un esempio fittizio, sostituisci con la logica reale
    return localStorage.getItem('authToken')
  }
}
