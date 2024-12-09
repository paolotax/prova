import { Controller } from "@hotwired/stimulus"
import Sortable from 'sortablejs';
import { patch } from '@rails/request.js'

// Connects to data-controller="tax-sortable"
export default class extends Controller {

  static values = {
    group: String
  }

  connect() {
    Sortable.create(this.element, {
      animation: 150,
      onEnd: this.onEnd.bind(this),
      group: this.groupValue,
    })
  }

  onEnd(event) {
    var sortableUpdateUrl = event.item.dataset.taxSortableUpdateUrl
    var sortableDataTappa = event.to.dataset.taxSortableDataTappa

    patch(sortableUpdateUrl, {
      body: JSON.stringify({position: event.newIndex, data_tappa: sortableDataTappa}),
    })
  }
}
