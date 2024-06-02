import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["item", "content"];
  static values = { initialTab: Number };
  static classes = ["activeItem"];

  connect() {
    this.#loadInitialTab();
  }

  update(event) {
    this.itemTargets.forEach(item => item.classList.remove(...this.activeItemClasses));

    event.currentTarget.classList.add(...this.activeItemClasses);
  }

  // private

  #loadInitialTab() {
    if (!this.initialTabValue) { return; }

    this.#initialTab.classList.add(...this.activeItemClasses);

    this.contentTarget.src = this.#initialTab.href;
  }

  get #initialTab() {
    return this.itemTargets[this.#index];
  }

  get #index() {
    return this.initialTabValue - 1;
  }
}
