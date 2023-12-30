import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="openmodal"
export default class extends Controller {

  static outlets = [ "modal" ]

  connect() {
  }

  open() {
    this.modalOutlet.open()
  }
}
