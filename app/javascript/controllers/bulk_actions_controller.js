import CheckboxesController from "./checkboxes_controller";
import { enter, leave } from "./helpers/transitions";

export default class BulkActionsController extends CheckboxesController {
  static targets = ["container", "form", "counter"];
  static values = { open: Boolean };

  // toggle(event) {
  //   super.toggle(event);
    
  //   console.log("toggle");
    
  //   this.#syncSelection();
  // }

  hide(event) {
    this.element.contains(event.target) || this.setCheckboxesTo(false);
  }

  // private

  checkboxesCheckedCountValueChanged() {
    this.counterTargets.forEach(counter => counter.textContent = this.checkboxesCheckedCount);

    this.openValue = this.checkboxesCheckedCount;
    
    this.#syncSelection();
  }

  openValueChanged() {
    this.openValue ? this.containerTarget.hidden && enter(this.containerTarget) : leave(this.containerTarget);
  }

  #syncSelection() {
    const name = this.checkboxes[0]?.name || "ids[]";
    console.log(name);
    this.formTargets.forEach(form => {
      form.querySelectorAll(`input[name="${name}"]`).forEach(input => input.remove());

      Array.from(this.checkboxes)
        .filter(checkbox => checkbox.checked)
        .forEach(checkbox => {
          form.appendChild(Object.assign(
            document.createElement("input"), { type: "hidden", name, value: checkbox.value }
          ));
        });
    });
  }
}
