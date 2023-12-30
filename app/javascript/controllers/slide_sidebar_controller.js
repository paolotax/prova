import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="slide-sidebar"
export default class extends Controller {

  static outlets = [ "slideover" ]

  toggle() {
    this.slideoverOutlet.toggle()
  }
}
