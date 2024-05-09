import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="replace"
export default class extends Controller {
  // click->replace#swap
  swap() {
    fetch("/test/replace", {
      method: "POST",
      headers: {
        Accept: "text/vnd.turbo-stream.html"
      }
    })
      .then(r => r.text())
      .then(html => Turbo.renderStreamMessage(html))

    // html: <turbo-stream action="replace"> ...</turbo-stream>
  }
}