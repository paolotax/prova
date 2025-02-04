import CheckboxesController from "./checkboxes_controller";
import { enter, leave } from "./helpers/transitions";

export default class BulkActionsController extends CheckboxesController {
  static targets = ["container", "form", "counter", "stampaForm", "tappaForm", "statoForm", "eliminaForm"];
  static values = { open: Boolean };

  toggle(event) {
    super.toggle(event);
        
    this.#syncSelection();
  }

  hide(event) {
    this.element.contains(event.target) || this.setCheckboxesTo(false);
  }

  
  // mie d togliere

  toggleTappa() {
    if (this.hasStampaFormTarget) {
      this.stampaFormTarget.classList.add('hidden')
    }

    if (this.hasStatoFormTarget) {
      this.statoFormTarget.classList.add('hidden')
    }
    
    if (this.tappaFormTarget.classList.contains('hidden')) {
      this.tappaFormTarget.classList.remove('hidden')
      // Trigger enter animation
      requestAnimationFrame(() => {
        this.tappaFormTarget.classList.remove('-translate-y-4', 'opacity-0')
        this.tappaFormTarget.classList.add('translate-y-0', 'opacity-100')
      })
    } else {
      // Trigger leave animation
      this.tappaFormTarget.classList.add('-translate-y-4', 'opacity-0')
      this.tappaFormTarget.classList.remove('translate-y-0', 'opacity-100')
      setTimeout(() => {
        this.tappaFormTarget.classList.add('hidden')
      }, 200)
    }
  }

  toggleStato() {
    this.tappaFormTarget.classList.add('hidden')
    
    if (this.hasStampaFormTarget) {
      this.stampaFormTarget.classList.add('hidden')
    }
    
    if (this.statoFormTarget) {
      if (this.statoFormTarget.classList.contains('hidden')) {
        this.statoFormTarget.classList.remove('hidden')
        requestAnimationFrame(() => {
          this.statoFormTarget.classList.remove('-translate-y-4', 'opacity-0')
          this.statoFormTarget.classList.add('translate-y-0', 'opacity-100')
        })
      } else {
        this.statoFormTarget.classList.add('-translate-y-4', 'opacity-0')
        this.statoFormTarget.classList.remove('translate-y-0', 'opacity-100')
        setTimeout(() => {
          this.statoFormTarget.classList.add('hidden')
        }, 200)
      }
    }
  }

  stampa() {
    this.tappaFormTarget.classList.add('hidden')
    this.statoFormTarget.classList.add('hidden')
    
    if (this.stampaFormTarget.classList.contains('hidden')) {
      this.stampaFormTarget.classList.remove('hidden')
      requestAnimationFrame(() => {
        this.stampaFormTarget.classList.remove('-translate-y-4', 'opacity-0')
        this.stampaFormTarget.classList.add('translate-y-0', 'opacity-100')
      })
    } else {
      this.stampaFormTarget.classList.add('-translate-y-4', 'opacity-0')
      this.stampaFormTarget.classList.remove('translate-y-0', 'opacity-100')
      setTimeout(() => {
        this.stampaFormTarget.classList.add('hidden')
      }, 200)
    }
  }

  toggleElimina() {
    this.eliminaFormTarget.classList.toggle('hidden')
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
