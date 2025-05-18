import { Controller } from "@hotwired/stimulus";
import { enter, leave } from "controllers/helpers/transitions";
import { classNames } from "controllers/helpers/class_names";
import { computePosition, offset, flip, shift } from "floating-ui";

export default class extends Controller {
  static targets = ["tooltip"];
  static values = {
    content: String,
    position: {type: String, default: "top"},
    offset: {type: Number, default: 2},
    theme: {type: String, default: "light"},
    interactionMode: {type: String, default: "hover"}
  };

  connect() {
    if (!this.hasContentValue) { return; }

    this.#setupTooltip();
  }

  show() {
    this.#computePosition();

    enter(this.tooltipTarget);
  }

  hide() {
    if (!this.hasTooltipTarget) { return; }

    leave(this.tooltipTarget);
  }

  hideOnClick() {
    if (!this.hasTooltipTarget) { return; }
    if (this.element.contains(event.target)) { return; }

    this.hide();
  }

  disconnect() {
    if (!this.hasTooltipTarget) { return; }

    this.tooltipTarget.remove();
  }

  // private

  #setupTooltip() {
    this.element.insertAdjacentHTML("beforeend", this.#tooltip);

    if (this.element.hasAttribute("aria-describedby")) {
      this.tooltipTarget.setAttribute("id", this.element.getAttribute("aria-describedby"));
    }

    Object.entries(this.#transitionData).forEach(([key, value]) => {
      this.tooltipTarget.setAttribute(key, value);
    });

    this.element.setAttribute("data-action", this.#tooltipActions);
  }

  #computePosition() {
    computePosition(this.element, this.tooltipTarget, {
      placement: this.#validatedPositionValue,
      middleware: [offset(this.offsetValue), flip(), shift({padding: 3})],
    }).then(({x, y}) => {
      Object.assign(this.tooltipTarget.style, {
        left: `${x}px`,
        top: `${y}px`,
      });
    });
  }

  get #tooltip() {
    return `
      <span
        role="tooltip"
        data-tooltip-target="tooltip"
        hidden="hidden"
        class="${this.#tooltipCSS}"
      >
        ${this.contentValue}
      </span>
    `;
  }

  get #transitionData() {
    return {
      // A delay (`delay-100`) is added _only_ on hover, so users don't accidentally trigger the toolip
      "data-transition-enter": classNames({"transition ease-out duration-200": true, "delay-100": !this.#isClickInteractionMode}),
      "data-transition-enter-start": "opacity-0 scale-95",
      "data-transition-enter-end": "opacity-100 scale-100",
      "data-transition-leave": "transition ease-out duration-300",
      "data-transition-leave-start": "opacity-100 scale-100",
      "data-transition-leave-end": "opacity-0 scale-105"
    };
  }

  get #tooltipActions() {
    return this.#isClickInteractionMode ?
      "click->tooltip#show click@window->tooltip#hideOnClick turbo:before-cache@window->tooltip#hide" :
      "mouseenter->tooltip#show mouseleave->tooltip#hide turbo:before-cache@window->tooltip#hide";
  }

  get #tooltipCSS() {
    const textClass = this.#isLightTheme ? "text-gray-700" : "text-gray-100";
    const backgroundClass = this.#isLightTheme ? "bg-white" : "bg-gray-800";
    const ringClass = this.#isLightTheme ? "ring-gray-300/50" : "ring-gray-900";

    return `
      absolute top-0 left-0
      px-2 py-1 text-sm leading-tight ${textClass}
      max-w-content
      ${backgroundClass}
      ring-1 ring-offset-0 ${ringClass}
      rounded-md shadow-lg
      z-10
    `;
  }

  get #validatedPositionValue() {
    if (this.#allowedPositions.includes(this.positionValue)) {
      return this.positionValue;
    } else {
      console.error(`Invalid position value: ${this.positionValue}. Must be one of ${this.#allowedPositions.join(", ")}.`);

      return "top";
    }
  }

  get #isLightTheme() {
    return this.themeValue == "light" ? true : false;
  }

  get #isClickInteractionMode() {
    return this.interactionModeValue == "click";
  }

  get #allowedPositions() {
    return ["top", "top-start", "top-end", "right", "right-start", "right-end", "bottom", "bottom-start", "bottom-end", "left", "left-start", "left-end"];
  }
}
