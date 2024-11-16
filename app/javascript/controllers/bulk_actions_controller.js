import CheckboxesController from "./checkboxes_controller";
import { enter, leave } from "./helpers/transitions";

export default class BulkActionsController extends CheckboxesController {
  static targets = ["container", "form", "counter"];
  static values = { open: Boolean };

  // private

  checkboxesCheckedCountValueChanged() {
    this.counterTargets.forEach(counter => counter.textContent = this.checkboxesCheckedCount);

    this.openValue = this.checkboxesCheckedCount;
  }

  openValueChanged() {
    this.openValue ? this.containerTarget.hidden && enter(this.containerTarget) : leave(this.containerTarget);
  }
}
