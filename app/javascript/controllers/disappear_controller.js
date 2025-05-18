import { Controller } from "@hotwired/stimulus";
import { leave } from "controllers/helpers/transitions";

export default class extends Controller {
  connect() {
    leave(this.element).then(() => {
      this.element.remove();
    })
  }
}
