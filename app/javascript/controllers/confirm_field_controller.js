import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["button", "source"];
  static values = { matcher: String, confirmed: { type: Boolean, default: false } };

  connect() {
    this.#setButtonsState(false);
  }

  validate() {
    this.confirmedValue = this.#isValid;
  }

  // private

  confirmedValueChanged() {
    this.confirmedValue ?
      this.#setButtonsState(true) :
      this.#setButtonsState(false);
  }

  #setButtonsState(enabled) {
    (this.hasButtonTarget ? [this.buttonTarget] : this.#submitButtons)
      .forEach(button => button.disabled = !enabled);
  }

  #textFieldMatch() {
    return this.sourceTarget.value === this.matcherValue;
  }

  #boxesChecked() {
    return this.sourceTargets.every(checkbox => checkbox.checked);
  }

  get #isValid() {
    return this.sourceTarget.type === "text" ?
      this.#textFieldMatch() :
      this.#boxesChecked();
  }

  get #submitButtons() {
    return this.element.querySelectorAll('input[type="submit"], button[type="submit"]');
  }
}
