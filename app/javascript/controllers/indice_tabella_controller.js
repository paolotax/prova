import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="indice-tabella"
export default class extends Controller {
  connect() {
    console.log("Connected to indice-tabella")
  }
}
