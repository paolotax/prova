import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["libroSelect", "scuolaSelect"]

  connect() {
    this.toggleQrcodableSelect();
  }

  toggleQrcodableSelect() {
    const selectedType = this.element.value;
    
    if (selectedType === "Libro") {
      this.libroSelectTarget.classList.remove("hidden");
      this.scuolaSelectTarget.classList.add("hidden");
    } else if (selectedType === "Scuola") {
      this.libroSelectTarget.classList.add("hidden");
      this.scuolaSelectTarget.classList.remove("hidden");
    } else {
      this.libroSelectTarget.classList.add("hidden");
      this.scuolaSelectTarget.classList.add("hidden");
    }
  }
} 