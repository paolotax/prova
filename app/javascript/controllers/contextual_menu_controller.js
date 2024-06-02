import { Controller } from "@hotwired/stimulus";
import { computePosition, offset, flip, shift } from "floating-ui";
import { enter, leave } from "./helpers/transitions";
import { verticalNavigation, horizontalNavigation } from "./helpers/keyboard_navigation";

export default class extends Controller {
  static targets = ["menu"];
  static values = {
    position: {type: String, default: "bottom-start"},
    offset: {type: Number, default: 0},
    orientation: {type: String, default: "vertical"},
    key: { type: String, default: "Escape" }
  };

  disconnect() {
    if (!this.hasMenuTarget) { return; }

    this.menuTarget.setAttribute("hidden", true);
  }

  show(event) {
    if (!this.hasMenuTarget) { return; }

    event.preventDefault();

    this.#computePosition(event);

    enter(this.menuTarget).then(() => {
      this.menuTarget.focus();
    });
  }

  navigate() {
    if (this.orientationValue == "horizontal") {
      horizontalNavigation(this.menuTarget, ["a", "button"]);
    } else {
      verticalNavigation(this.menuTarget, ["a", "button"]);
    }
  }

  hide() {
    if (!this.hasMenuTarget) { return; }

    leave(this.menuTarget);
  }

  hideOnClick() {
    if (!this.hasMenuTarget) { return; }
    if (this.menuTarget.contains(event.target)) { return; }

    this.hide();
  }

  hideWithKey(event) {
    if (!this.hasMenuTarget) { return; }
    if (this.menuTarget.hasAttribute("hidden")) { return; }

    if (event.key === this.keyValue) {
      this.hide()
    }
  }

  // private

  #computePosition(event) {
    computePosition(this.#virtualElement(event), this.menuTarget, {
      placement: this.#validatedPositionValue,
      middleware: [offset(this.offsetValue), flip(), shift({padding: 3})],
    }).then(({x, y}) => {
      Object.assign(this.menuTarget.style, {
        left: `${x}px`,
        top: `${y}px`,
      });
    });
  }

  #virtualElement(event) {
    const { clientY: mouseY, clientX: mouseX } = event;

    return {
      getBoundingClientRect() {
        return {
          width: 0,
          height: 0,
          top: mouseY,
          right: mouseX,
          bottom: mouseY,
          left: mouseX,
        }
      }
    }
  }

  get #validatedPositionValue() {
    if (this.#allowedPositions.includes(this.positionValue)) {
      return this.positionValue;
    } else {
      console.error(`Invalid position value: ${this.positionValue}. Must be one of ${this.#allowedPositions.join(", ")}.`);

      return "bottom-start";
    }
  }

  get #allowedPositions() {
    return ["top", "top-start", "top-end", "right", "right-start", "right-end", "bottom", "bottom-start", "bottom-end", "left", "left-start", "left-end"];
  }
}
