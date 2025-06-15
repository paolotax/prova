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
      swapThreshold: 0.55,
      group: this.groupValue,
      handle: '.handle',
      filter: '.filtered'
    })
  }

  onEnd(event) {
    const item = event.item
    const newPosition = event.newIndex + 1

    patch(`/stats/${item.dataset.id}/sort`, {
      body: JSON.stringify({position: newPosition}),
      headers: {
        Accept: "text/vnd.turbo-stream.html"
      }
    })
  }
}
