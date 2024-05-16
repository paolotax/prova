import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static outlets = ["command-menu"];

  open() {
    this.commandMenuOutlet.open();
  }
}
