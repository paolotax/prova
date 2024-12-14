import { Controller } from "@hotwired/stimulus"
import Sortable from 'sortablejs';
import { patch } from '@rails/request.js'

// Connects to data-controller="tax-sortable"
export default class extends Controller {

  static targets = ["handle"]
  static values = {
    group: String
  }

  connect() {
    Sortable.create(this.element, {
      animation: 150,
      onEnd: this.onEnd.bind(this),
      swapThreshold: 0.55,
      group: this.groupValue,
      handle: '.handle',
      filter: '.filtered'
    })
  }

  onEnd(event) {
    var sortableUpdateUrl = event.item.dataset.taxSortableUpdateUrl
    var dataTappa = event.to.dataset.taxSortableDataTappa
    var newPosition = event.newIndex + 1
    patch(sortableUpdateUrl, {
      body: JSON.stringify({position: newPosition, data_tappa: dataTappa}),
      headers: {
        Accept: "text/vnd.turbo-stream.html"
      }
    })
  }
}
