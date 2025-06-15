import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["item"];
  static classes = ["touch"];

  connect() {
    this.#observer.observe(this.element, { childList: true, subtree: true });
  }

  // private

  #handleMutations(mutations) {
    mutations
      .filter(mutation => mutation.type === "childList")
      .forEach(mutation => this.#processAddedNodes(mutation.addedNodes))
  }

  #processAddedNodes(addedNodes) {
    addedNodes.forEach(node => {
      if (this.#isClone(node)) {
        this.#handleNewItem(node)
      }
    })
  }

  #isClone(node) {
    return node.nodeType === Node.ELEMENT_NODE &&
           node.hasAttribute("data-clone-marker-target");
  }

  #handleNewItem(newItem) {
    const existingItem = this.#findMatchingItem(newItem);

    if (existingItem) {
      this.#touchExistingItem(existingItem);

      newItem.remove();
    }
  }

  #findMatchingItem(newItem) {
    return this.itemTargets.find(item =>
      item !== newItem &&
        this.#itemMatch(item, newItem)
    )
  }

  #touchExistingItem(item) {
    item.classList.remove(...this.touchClasses);

    void item.offsetWidth;

    item.classList.add(...this.touchClasses);
  }

  #itemMatch(current_item, new_item) {
    return current_item.textContent.trim() === new_item.textContent.trim();
  }

  get #observer() {
    return new MutationObserver(this.#handleMutations.bind(this));
  }
}
