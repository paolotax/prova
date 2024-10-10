import { Controller } from "@hotwired/stimulus";
import { leave } from "./helpers/transitions";

export default class extends Controller {
  connect() {
    leave(this.element).then(() => {
      this.element.remove();
    })
  }
}
