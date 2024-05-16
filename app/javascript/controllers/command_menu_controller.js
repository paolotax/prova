import { Controller } from "@hotwired/stimulus";
import { enter, leave } from "./helpers/transitions";
import { verticalNavigation } from "./helpers/keyboard_navigation";

export default class extends Controller {
  static targets = ["input", "itemsList", "item"];
  static values = {
    showKey: { type: String, default: null },
    hideKey: { type: String, default: "Escape" },
    open: { type: Boolean, default: false },
    listOpen: { type: Boolean, default: true },
    filtering: { type: Boolean, default: false },
    minimumCharacters: { type: Number, default: 3 },
    collapse: Boolean
  };

  disconnect() {
    this.openValue = false;
  }

  showWithKey() {
    if (!this.showKeyValue) { return; }
    if (this.openValue) { return; }

    if (event.key === this.showKeyValue && event.metaKey) {
      this.open();

      event.preventDefault();
    }
  }

  typeInput() {
    if (this.#shouldIgnoreTypeInput(event)) { return; }

    this.#focusToEnd(this.inputTarget);
  }

  hideWithKey(event) {
    if (!this.openValue) { return; }

    if (event.key === this.hideKeyValue) { this.openValue = false; }
  }

  open() {
    this.openValue = true;

    this.listOpenValue = !this.collapseValue;
  }

  hide() {
    if (this.#isFromCommandMenuButton(event)) { return; }
    if (this.inputTarget.contains(event.target)) { return; }

    this.openValue = false;
  }

  navigate() {
    verticalNavigation(this.itemsListTarget, ["button"], true);
  }

  focus() {
    event.currentTarget.focus();
  }

  filter() {
    let filterText = this.inputTarget.value.trim().toLowerCase();

    if (filterText.length < this.minimumCharactersValue) {
      this.itemTargets.forEach(item => item.hidden = this.collapseValue);

      this.listOpenValue = false;
    } else {
      this.itemTargets.forEach(item => {
        const attribute = item.getAttribute("data-command-menu-attribute").toLowerCase();

        this.listOpenValue = true;

        item.hidden = !attribute.includes(filterText);
      });
    }
  }

  // private

  openValueChanged() {
    if (this.openValue) {
      this.element.classList.add("flex");

      enter(this.element).then(() => {
        this.inputTarget.focus();
      });
    } else {
      leave(this.element).then(() => {
        this.element.classList.remove("flex");

        this.#houseKeeping();
      });
    }
  }

  #shouldIgnoreTypeInput(event) {
    return !this.openValue ||
           event.key === this.hideKeyValue ||
           document.activeElement === this.inputTarget ||
           !(event.key === "Backspace" || event.key.match(/^[a-z0-9]$/i));

  }

  #focusToEnd(element) {
    element.focus();
    element.setSelectionRange(element.value.length, element.value.length);
  }

  #houseKeeping() {
    this.inputTarget.value = null;

    this.#resetFilter();
  }

  #resetFilter() {
    this.itemTargets.forEach(item => item.hidden = this.collapseValue);
  }

  #isFromCommandMenuButton(event) {
    return event.target.getAttribute("data-controller") === "command-menu--button";
  }
}
