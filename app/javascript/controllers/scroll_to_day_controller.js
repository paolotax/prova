import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="scroll-to-day"
export default class extends Controller {

  static values = { giorno: String } // Riceve il parametro "giorno"

  connect() {
    console.log("Connected to scroll-to-day controller");
    if (this.giornoValue) {
      // Trova l'elemento corrispondente
      const giornoElement = document.querySelector(`[data-giorno="${this.giornoValue}"]`);
      if (giornoElement) {
        // Scorri fino all'elemento
        giornoElement.scrollIntoView({ behavior: "instant", inline: "center" });
        window.scrollTo(0, 0);
        // Aggiungi la classe active
        // giornoElement.classList.remove("bg-white");
        // giornoElement.classList.add("bg-pink-100", "ring-2", "ring-red-500", "rounded-md");
        
        
      }
    }
  }
}