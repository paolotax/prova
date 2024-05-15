import { Controller } from "@hotwired/stimulus";
import { enter, leave } from "./helpers/transitions";
import { computePosition, offset, flip, shift } from "floating-ui";
import { verticalNavigation } from "./helpers/keyboard_navigation";

export default class extends Controller {
  static targets = ["button", "menu"];
  static values = {
    open: { type: Boolean, default: false },
    key: { type: String, default: "Escape" },
    position: { type: String, default: "bottom-end" },
    offset: { type: Number, default: 2 },
  };

  disconnect() {
    this.openValue = false;
  }

  toggle() {
    this.openValue = !this.openValue;
  }

  hide(event) {
    if (!this.openValue) return;

    if (this.element.contains(event.target) === false) {
      this.openValue = false;
    }
  }

  hideWithKey(event) {
    if (!this.openValue) return;

    if (event.key === this.keyValue) {
      this.openValue = false;
    }
  }

  navigate() {
    verticalNavigation(this.menuTarget);
  }

  // private

  openValueChanged() {
    if (this.openValue) {
      this.#showMenu();

      this.#computePosition();
    } else {
      this.#hideMenu();
    }
  }

  #showMenu() {
    enter(this.menuTarget);
  }

  #hideMenu() {
    leave(this.menuTarget);
  }

  #computePosition() {
    computePosition(this.buttonTarget, this.menuTarget, {
      placement: this.positionValue,
      middleware: [offset(this.offsetValue), flip(), shift({padding: 3})],
    }).then(({x, y}) => {
      Object.assign(this.menuTarget.style, {
        left: `${x}px`,
        top: `${y}px`,
      });
    });
  }
}
