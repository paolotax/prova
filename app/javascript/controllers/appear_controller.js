import { Controller } from "@hotwired/stimulus";
import { enter } from "./helpers/transitions";

export default class extends Controller {
  connect() {
    enter(this.element);
  }
}
