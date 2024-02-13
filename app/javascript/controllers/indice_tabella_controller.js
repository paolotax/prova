import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="indice-tabella"
export default class extends Controller {
  connect() {
    console.log("Connected to indice-tabella")
  }

  changeGroup(event) {
    
    // Get the selected value
    const selectedValue = event.target.value
    console.log(selectedValue)

    // Get the table rows
    const rows = this.element.querySelectorAll("tbody tr")
    console.log(rows.length)

    // Loop through the rows
    rows.forEach(row => {
      // Get the group value from the row
      const group = row.dataset.group
      console.log(group === selectedValue)

      // If the selected value is "all" or the group value matches the selected value, show the row
      if (selectedValue === "all" || group === selectedValue) {
        // row.classList.remove("hidden");
        row.style.display = "table-row"
      } else {
        // Otherwise, hide the row
        // row.classList.add("hidden");
        row.style.display = "none"
      }
    })
  }
    

}
