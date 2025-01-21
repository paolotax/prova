import CheckboxesController from "./checkboxes_controller";
import { enter, leave } from "./helpers/transitions";

export default class BulkActionsController extends CheckboxesController {
  static targets = ["container", "form", "counter", "checkbox"];
  static values = { open: Boolean };


  connect() {
    this.formTargets.forEach(form => {
      form.addEventListener("submit", this.handleFormSubmit.bind(this));
    });
  }

  disconnect() {
    this.formTargets.forEach(form => {
      form.removeEventListener("submit", this.handleFormSubmit.bind(this));
    });
  }

  handleFormSubmit(event) {
    event.preventDefault();
    const form = event.target;
    const formData = this.buildFormData(form);
    const headers = this.getRequestHeaders(form);

    if (form.action.endsWith('.pdf')) {
      this.handlePdfSubmission(form, formData, headers);
    } else {
      this.handleStandardSubmission(form, formData, headers);
    }
  }

  buildFormData(form) {
    const formData = new FormData(form);
    const checkedIds = this.getCheckedIds();
    
    checkedIds.forEach(id => {
      const checkbox = this.checkboxTargets.find(cb => cb.value === id);
      const objectName = checkbox.name.replace(/\[\]$/, '');
      formData.append(`${objectName}[]`, id);
    });

    return formData;
  }

  getCheckedIds() {
    return this.checkboxTargets
      .filter(checkbox => checkbox.checked)
      .map(checkbox => checkbox.value);
  }

  getRequestHeaders(form) {
    return {
      "Accept": form.action.endsWith('.pdf') 
        ? "application/pdf" 
        : "text/vnd.turbo-stream.html"
    };
  }


  handlePdfSubmission(form, formData, headers) {
    fetch(form.action, {
      method: form.method,
      body: formData,
      headers: headers
    })
    .then(response => response.blob())
    .then(blob => {
      const url = window.URL.createObjectURL(blob);
      window.open(url, '_blank');
    });
  }

  handleStandardSubmission(form, formData, headers) {
    fetch(form.action, {
      method: form.method,
      body: formData,
      headers: headers
    });
  }

  // private

  checkboxesCheckedCountValueChanged() {
    this.counterTargets.forEach(counter => counter.textContent = this.checkboxesCheckedCount);

    this.openValue = this.checkboxesCheckedCount;
  }

  openValueChanged() {
    this.openValue ? this.containerTarget.hidden && enter(this.containerTarget) : leave(this.containerTarget);
  }
}
