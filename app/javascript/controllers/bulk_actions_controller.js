import CheckboxesController from "./checkboxes_controller";
import { enter, leave } from "./helpers/transitions";

export default class BulkActionsController extends CheckboxesController {
  static targets = ["container", "form", "counter", "formContainer"];
  static values = { open: Boolean };

  toggle(event) {
    super.toggle(event);
        
    this.#syncSelection();
  }

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

  showCheckboxes(event) {
    console.log("showCheckboxes");
    event.preventDefault();
    document.querySelectorAll('.bulk-actions-checkbox').forEach(checkbox => {
      checkbox.classList.toggle('hidden');
    });
    document.querySelectorAll('.tappa-menu').forEach(menu => {
      menu.classList.toggle('hidden');
    });
  }
  
  selectCheckbox(event) {
    const tappaId = event.currentTarget.dataset.bulkActionsTappaParam;
    const checkbox = document.querySelector(`input[type="checkbox"][value="${tappaId}"]`);
    
    if (checkbox) {
        checkbox.checked = true;
        checkbox.dispatchEvent(new Event('change', { bubbles: true }));
        
        // Aggiorna il contatore e mostra il container
        this.checkboxesCheckedCountValue = this.checkboxes.filter(c => c.checked).length;
        this.openValue = true;
        this.#syncSelection();
    }
  }

  toggleFormContainer(event) {
    const formId = event.currentTarget.dataset.formId;
    const clickedButton = event.currentTarget;
    const allButtons = this.containerTarget.querySelectorAll('button, a');
    const closeButton = this.element.querySelector('[data-action="bulk-actions#deselectAll"]');
    
    // Trova la form target
    const targetForm = this.formContainerTargets.find(formContainer => 
        formContainer.dataset.formId === formId
    );
    
    // Se la form target è già visibile
    if (targetForm && !targetForm.classList.contains('hidden')) {
        // Nascondi la form
        targetForm.classList.add('hidden');
        targetForm.classList.remove('flex');
        // Mostra tutti i pulsanti
        allButtons.forEach(button => button.classList.remove('hidden'));
        return;
    }
    
    // Nascondi tutte le form
    this.formContainerTargets.forEach(formContainer => {
        formContainer.classList.add('hidden');
        formContainer.classList.remove('flex');
    });
    
    // Se c'è una form target
    if (targetForm) {
        // Nascondi tutti i pulsanti eccetto quello cliccato e il pulsante di chiusura
        allButtons.forEach(button => {
            if (button !== clickedButton && button !== closeButton) {
                button.classList.add('hidden');
            }
        });
        
        // Mostra la form selezionata
        targetForm.classList.remove('hidden');
        targetForm.classList.add('flex');
    }
  }
}
