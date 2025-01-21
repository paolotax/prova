import { Controller } from "@hotwired/stimulus";

export default class CheckboxesController extends Controller {
  static values = { checkboxesCheckedCount: Number };

  selectAll() {
    this.setCheckboxesTo(true);
  }

  deselectAll() {
    this.setCheckboxesTo(false);
  }

  toggle(event) {
    const checkbox = event.currentTarget.querySelector('input[type="checkbox"]')
    console.log("checkbox");
    checkbox.checked = !checkbox.checked

    this.count();
  }

  shiftClick(event) {
    if (event.shiftKey) {
      event.preventDefault();

      this.toggle(event);
    }
  }

  // private

  setCheckboxesTo(boolean) {
    this.checkboxes
      .filter(checkbox => !checkbox.disabled)
      .forEach(checkbox => checkbox.checked = boolean);

    this.count();
  }

  count() {
    this.checkboxesCheckedCountValue = this.checkboxesCheckedCount;
  }

  get checkboxesCheckedCount(){
    return this.checkboxes.filter(checkbox => checkbox.checked).length;
  }

  get checkboxes() {
    return Array(...this.element.querySelectorAll("input[type=checkbox]"));
  }
}
