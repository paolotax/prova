import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results", "select"]

  connect() {
    this.search()
  }

  updateType() {
    this.inputTarget.value = ""
    this.search()
  }

  async search() {
    const query = this.inputTarget.value
    const type = this.selectTarget.value
    
    const response = await fetch(`/searches/clientable?type=${type}&query=${query}`)
    const html = await response.text()
    
    this.resultsTarget.innerHTML = html
  }
} 