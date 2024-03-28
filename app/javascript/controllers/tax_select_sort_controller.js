import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tax-select-sort"
export default class extends Controller {
  params = new URLSearchParams(window.location.search)
  
  connect() {
    // attach action to the element
    this.element.dataset.action = "change->tax-select-sort#filter"
    // set initial params after page load
    this.element.value = this.params.get('sort')
  }

  filter() {
    const query = this.element.value
    this.params.set('sort', query)
    window.location.search = this.params.toString()
  }
}
