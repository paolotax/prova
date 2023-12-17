import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="form"
export default class extends Controller {
  
  
  connect() {
    console.log("Hello, Stimulus!", this.element)
  }

  initialize() {
    console.log("Hi, Stimulus!", this.element)
  }

  disconnect() { 
    console.log("Goodbye, Stimulus!", this.element)
  }

  submit() {
    this.element.requestSubmit();
  }

}
