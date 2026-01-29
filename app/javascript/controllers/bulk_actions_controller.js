import CheckboxesController from "controllers/checkboxes_controller";

export default class BulkActionsController extends CheckboxesController {
  static targets = ["container", "form", "counter", "formContainer", "menuButton"];
  static values = { open: Boolean };

  toggle(event) {
    super.toggle(event);
        
    this.#syncSelection();
  }

  hide(event) {
    this.element.contains(event.target) || this.setCheckboxesTo(false);
  }

  stopPropagation(event) {
    event.stopPropagation();
  }


  // private

  checkboxesCheckedCountValueChanged() {
    this.counterTargets.forEach(counter => counter.textContent = this.checkboxesCheckedCount);

    this.openValue = this.checkboxesCheckedCount;

    // Toggle data-has-selection on container to show/hide all checkboxes
    if (this.checkboxesCheckedCount > 0) {
      this.element.setAttribute("data-has-selection", "");
    } else {
      this.element.removeAttribute("data-has-selection");
    }

    this.#syncSelection();
  }

  openValueChanged() {
    if (this.openValue) {
      this.containerTarget.hidden = false;
      this.containerTarget.setAttribute("data-visible", "");
    } else {
      this.containerTarget.removeAttribute("data-visible");
      // Wait for CSS transition to complete before hiding
      setTimeout(() => {
        if (!this.openValue) this.containerTarget.hidden = true;
      }, 300);
    }
  }

  #syncSelection() {
    const name = this.checkboxes[0]?.name || "ids[]";
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
        // Mostra tutti i pulsanti del menu
        this.menuButtonTargets.forEach(button => button.classList.remove('hidden'));
        return;
    }
    
    // Nascondi tutte le form
    this.formContainerTargets.forEach(formContainer => {
        formContainer.classList.add('hidden');
        formContainer.classList.remove('flex');
    });
    
    // Se c'è una form target
    if (targetForm) {
        // Nascondi tutti i pulsanti del menu eccetto quello cliccato
        this.menuButtonTargets.forEach(button => {
            if (button !== clickedButton) {
                button.classList.add('hidden');
            }
        });
        
        // Mostra la form selezionata
        targetForm.classList.remove('hidden');
        targetForm.classList.add('flex');
    }
  }

  hideAfterSubmit(event) {
    // Hide with animation
    this.containerTarget.removeAttribute("data-visible");

    setTimeout(() => {
      this.containerTarget.hidden = true;

      // Reset form states
      this.formContainerTargets.forEach(formContainer => {
        formContainer.classList.add('hidden');
        formContainer.classList.remove('flex');
        formContainer.removeAttribute('data-active');
      });

      // Show all buttons
      this.menuButtonTargets.forEach(button => {
        button.classList.remove('hidden');
        button.hidden = false;
      });

      // Deselect all checkboxes
      this.setCheckboxesTo(false);
    }, 300);
  }

  toggleButtons(show) {
    this.menuButtonTargets.forEach(button => {
      button.style.display = show ? "block" : "none"
    })
  }
}
