


// copiato d FancyTailwind e tailwind-components ma da migliorare

import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="fancy-select"
export default class extends Controller {

  static targets = ['menu', 'button', 'menuItem', 'selected', 'input']
  static values  = { open: Boolean, default: false }

  connect() {
    if (this.hasButtonTarget) {
      console.log("has button target");
      this.buttonTarget.addEventListener("keydown", this._onMenuButtonKeydown)
      this.buttonTarget.setAttribute("aria-haspopup", "true")
    }
  }

  disconnect() {
    if (this.hasButtonTarget) {
      console.log("disconnected");
      this.buttonTarget.removeEventListener("keydown", this._onMenuButtonKeydown)
      this.buttonTarget.removeAttribute("aria-haspopup")
    }
  }

  openValueChanged() {

    console.log("openValueChanged");
    
    // transition(this.menuTarget, this.openValue)
    //this.menuTarget.classList.toggle("hidden");
    if (this.openValue === true && this.hasMenuItemTarget) {
      this.menuItemTargets[0].focus()
    }
  }

  show() {
    this.openValue = true;
  }

  hide(event) {
    if (event.target.nodeType && this.element.contains(event.target) === false && this.openValue) {
      this.openValue = false
    }
  }

  toggle() {
    if (this.menuTarget.classList.contains("hidden")) {
      this.menuTarget.classList.remove("hidden");
    } else {
      this.menuTarget.classList.add("hidden");
    }
  }

  nextItem() {
    const nextIndex = Math.min(this.currentItemIndex + 1, this.menuItemTargets.length - 1)
    this.menuItemTargets[nextIndex].focus()
  }

  previousItem() {
    const previousIndex = Math.max(this.currentItemIndex - 1, 0)
    this.menuItemTargets[previousIndex].focus()
  }

  get currentItemIndex() {
    return this.menuItemTargets.indexOf(document.activeElement)
  }

  choose(e) {
    const selectItem = e.currentTarget;
    const id = selectItem.dataset.id;
    console.log( e.currentTarget );

    this.selectedTarget.value = id;
    this.inputTarget.value = id;

    // // Copy the label HTML and place it into the outer form element]
    // this.selectedTarget.innerHTML =
    //   selectItem.querySelector(`[data-js="label"]`).outerHTML;
    // // Set the hidden inputs value to the ID
    // this.inputTarget.value = id;
    // Remove checkmarks from all other elements
    
    this.menuItemTargets.forEach((itemTarget) => {
      
      itemTarget
        .querySelector(`[data-js="title"]`)
        .classList.remove("font-semibold");
      
      itemTarget.querySelector(`[data-js="check"]`).classList.add("hidden");
      
      itemTarget.classList.remove("bg-slate-100");       
    });
    
    // Add checkmark to selected item.
    selectItem
      .querySelector(`[data-js="title"]`)
      .classList.add("font-semibold");

    selectItem.querySelector(`[data-js="check"]`).classList.remove("hidden");

    selectItem.classList.add("bg-slate-100");

    this.toggle();
  }
}