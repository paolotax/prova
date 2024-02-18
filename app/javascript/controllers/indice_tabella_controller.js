import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="indice-tabella"
export default class extends Controller {
  connect() {
    console.log("Connected to indice-tabella")
  }

  changeGroup(event) {
    
    // Get the selected value
    const selectedValue = event.target.value

    // Get the table rows
    const rows = this.element.querySelectorAll("tbody tr")
    console.log(rows.length)

    rows.forEach(row => {
      // Get the group value from the row
      const group = row.dataset.group

      // If the selected value is "all" or the group value matches the selected value, show the row
      if (selectedValue === "all" || group === selectedValue) {
        row.style.display = "table-row"
      } else {
        row.style.display = "none"
      }
    })
  }
    

}
