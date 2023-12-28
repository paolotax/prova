import { Controller } from "@hotwired/stimulus"


// CodePen Home
// Back-to-top (stimulus.js)
// Jason Zimdars
// Thankyou for the inspiration


// Connects to data-controller="viewport-entrance-toggle"
export default class extends Controller {

  initialize() {
    this.intersectionObserver = new IntersectionObserver(entries => this.processIntersectionEntries(entries))
  }

  connect() {
    this.intersectionObserver.observe(this.element)
  }

  disconnect() {
    this.intersectionObserver.unobserve(this.element)
  }

  // Private

  processIntersectionEntries(entries) {
    entries.forEach(entry => {
      this.element.classList.toggle(this.data.get("class"), entry.isIntersecting)
    })
  }
}



