import CheckboxesController from "controllers/checkboxes_controller";

export default class BulkActionsController extends CheckboxesController {
  static targets = ["container", "form", "counter", "formContainer", "menuButton", "listCounter"];
  static values = { open: Boolean };

  connect() {
    // Range select con shift: anchor = ultima checkbox toccata senza shift.
    // Listener registrati qui (non via data-action) così valgono per tutte
    // le liste che usano bulk-actions senza toccare le view.
    this.lastCheckbox = null;
    this.boundShiftSelect = this.#shiftSelect.bind(this);
    this.boundPreventShiftTextSelection = this.#preventShiftTextSelection.bind(this);
    this.element.addEventListener("click", this.boundShiftSelect);
    this.element.addEventListener("mousedown", this.boundPreventShiftTextSelection);
  }

  disconnect() {
    this.element.removeEventListener("click", this.boundShiftSelect);
    this.element.removeEventListener("mousedown", this.boundPreventShiftTextSelection);
  }

  toggle(event) {
    super.toggle(event);

    this.#syncSelection();
  }

  enterSelectionMode() {
    if (this.element.hasAttribute("data-has-selection")) {
      this.setCheckboxesTo(false);
      this.element.removeAttribute("data-has-selection");
      this.openValue = false;
    } else {
      this.element.setAttribute("data-has-selection", "");
      this.openValue = true;
    }
  }

  toggleCard(event) {
    if (event.shiftKey) return // gestito dal range select in #shiftSelect
    if (!this.element.hasAttribute("data-has-selection")) return

    // Let native checkbox clicks through, then count
    if (event.target.closest(".card__checkbox")) {
      requestAnimationFrame(() => this.count())
      return
    }

    const card = event.target.closest(".card")
    if (!card) return

    const checkbox = card.querySelector('.card__checkbox input[type="checkbox"]')
    if (!checkbox) return

    event.preventDefault()
    event.stopPropagation()

    checkbox.checked = !checkbox.checked
    this.count()
  }

  hide(event) {
    this.element.contains(event.target) || this.setCheckboxesTo(false);
  }

  stopPropagation(event) {
    event.stopPropagation();
  }


  // private

  // Shift+click: seleziona/deseleziona l'intervallo tra l'anchor e il target
  // (stile Gmail). Funziona sia sulla checkbox che sull'intera card/riga.
  #shiftSelect(event) {
    const checkbox = event.target.closest?.("input[type=checkbox]");

    if (checkbox && this.checkboxes.includes(checkbox)) {
      if (event.shiftKey && this.lastCheckbox && this.lastCheckbox !== checkbox) {
        this.#applyRange(this.lastCheckbox, checkbox, checkbox.checked);
      }
      this.lastCheckbox = checkbox;
      return;
    }

    if (!event.shiftKey) return;

    const item = event.target.closest(".card, .data-row");
    if (!item || !this.element.contains(item)) return;

    const itemCheckbox = item.querySelector("input[type=checkbox]");
    if (!itemCheckbox || itemCheckbox.disabled) return;

    // Niente navigazione dal link overlay: shift+click = selezione
    event.preventDefault();
    event.stopPropagation();

    if (this.lastCheckbox && this.lastCheckbox !== itemCheckbox) {
      this.#applyRange(this.lastCheckbox, itemCheckbox, this.lastCheckbox.checked);
    } else {
      itemCheckbox.checked = !itemCheckbox.checked;
      this.count();
    }
    this.lastCheckbox = itemCheckbox;
  }

  #applyRange(from, to, state) {
    const boxes = this.checkboxes;
    let start = boxes.indexOf(from);
    let end = boxes.indexOf(to);
    if (start === -1 || end === -1) return;
    if (start > end) [start, end] = [end, start];

    for (let i = start; i <= end; i++) {
      if (!boxes[i].disabled) boxes[i].checked = state;
    }
    this.count();
  }

  // Evita la selezione del testo quando si fa shift+click sulle liste
  #preventShiftTextSelection(event) {
    if (event.shiftKey && event.target.closest(".card, .data-row")) {
      event.preventDefault();
    }
  }

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

      // Update list counter after DOM settles
      this.#updateListCounter();
    }, 300);
  }

  #updateListCounter() {
    if (!this.hasListCounterTarget) return

    // Count remaining cards in the list
    const count = this.element.querySelectorAll(".card").length
    this.listCounterTarget.textContent = `(${count})`
  }

  toggleButtons(show) {
    this.menuButtonTargets.forEach(button => {
      button.style.display = show ? "block" : "none"
    })
  }
}
