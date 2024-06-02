import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["item", "content", "option"];
  static values = { initialTab: Number };
  static classes = ["activeItem"];

  connect() {
    this.#loadInitialTab();
  }

  update(event) {
    this.itemTargets.forEach(item => item.classList.remove(...this.activeItemClasses));

    event.currentTarget.classList.add(...this.activeItemClasses);
  }

  change(event) {

    let src = this.optionTarget.options[this.optionTarget.selectedIndex].value
    this.itemTargets.forEach(item => item.classList.remove(...this.activeItemClasses));

    event.currentTarget.classList.add(...this.activeItemClasses);

    console.log(src);

    document.getElementById("search_results").src = src;

    // this.contentTarget.src = src;
  }

  // private

  #loadInitialTab() {
    if (!this.initialTabValue) { return; }
    console.log("this.#initialTab")
    this.#initialTab.classList.add(...this.activeItemClasses);
    // non carico il contenuto iniziale ma devo farlo solo quando clicco se no non funziona nella stessa pagina 
    // this.contentTarget.src = this.#initialTab.href;
  }

  get #initialTab() {
    return this.itemTargets[this.#index];
  }

  get #index() {
    return this.initialTabValue - 1;
  }
}
