import { Controller } from "@hotwired/stimulus"
import Sortable from 'sortablejs';
import { patch } from '@rails/request.js'

// Connects to data-controller="tax-sortable"
export default class extends Controller {

  static targets = ["handle", "item"]
  static values = {
    group: String
  }

  connect() {
    Sortable.create(this.element, {
      animation: 150,
      onEnd: this.onEnd.bind(this),
      setData: this.setData.bind(this),
      swapThreshold: 0.55,
      group: this.groupValue,
      filter: '.filtered'
    })
  }

  setData(dataTransfer, dragEl) {
    const tappaId = dragEl.dataset.tappaId
    if (tappaId) {
      const name = dragEl.querySelector(".tappa-compact__name")?.textContent?.trim() || ""
      dataTransfer.setData("application/x-tappa-ids", JSON.stringify([{ id: tappaId, name }]))
    }
  }

  onEnd(event) {
    var sortableUpdateUrl = event.item.dataset.taxSortableUpdateUrl
    if (!sortableUpdateUrl) return

    var dataTappa = event.to.dataset.taxSortableDataTappa
    var newPosition = event.newIndex + 1
    patch(sortableUpdateUrl, {
      body: JSON.stringify({ position: newPosition, data_tappa: dataTappa ?? null })
    })
  }
}
