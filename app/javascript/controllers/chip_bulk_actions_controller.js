import { Controller } from "@hotwired/stimulus";

// Gestisce il ciclo a 3 stati delle chip nella pagina bolla:
//   neutra (no class) → active → negative → neutra
// - active: assegnata in consegna (server-persisted via PATCH)
// - negative: assegnata + selezionata per bulk (client-only)
// La selection viene serializzata in un hidden JSON dentro i form bulk-bar.
export default class extends Controller {
  static targets = ["form", "counter", "bar"];
  static values = { selection: { type: Object, default: {} } };

  connect() {
    this.selectionValue = {};
  }

  toggleChip(event) {
    event.preventDefault();
    const chip = event.currentTarget;
    const clientableType = chip.dataset.clientableType;
    const clientableId = chip.dataset.clientableId;
    const rigaId = chip.dataset.bollaVisioneRigaId;
    const toggleUrl = chip.dataset.toggleUrl;

    if (chip.classList.contains("negative")) {
      this._removeFromSelection(clientableType, clientableId, rigaId);
      chip.classList.remove("negative", "active");
      this._patchToggle(toggleUrl);
    } else if (chip.classList.contains("active")) {
      this._addToSelection(clientableType, clientableId, rigaId);
      chip.classList.remove("active");
      chip.classList.add("negative");
    } else {
      chip.classList.add("active");
      this._patchToggle(toggleUrl);
    }
  }

  selectionValueChanged() {
    this._syncForms();
    this._updateCounter();
  }

  hideAfterSubmit() {
    this.selectionValue = {};
    this.element.querySelectorAll(".classi-chip.negative").forEach(chip => {
      chip.classList.remove("negative");
    });
  }

  _addToSelection(type, id, rigaId) {
    const next = JSON.parse(JSON.stringify(this.selectionValue));
    next[type] ||= {};
    next[type][id] ||= [];
    if (!next[type][id].includes(rigaId)) next[type][id].push(rigaId);
    this.selectionValue = next;
  }

  _removeFromSelection(type, id, rigaId) {
    const next = JSON.parse(JSON.stringify(this.selectionValue));
    if (next[type] && next[type][id]) {
      next[type][id] = next[type][id].filter(x => x !== rigaId);
      if (next[type][id].length === 0) delete next[type][id];
      if (Object.keys(next[type]).length === 0) delete next[type];
    }
    this.selectionValue = next;
  }

  _syncForms() {
    const json = JSON.stringify(this.selectionValue);
    this.formTargets.forEach(form => {
      let input = form.querySelector('input[name="selection_json"]');
      if (!input) {
        input = Object.assign(document.createElement("input"), { type: "hidden", name: "selection_json" });
        form.appendChild(input);
      }
      input.value = json;
    });
  }

  _updateCounter() {
    const count = Object.values(this.selectionValue)
      .flatMap(byId => Object.values(byId))
      .reduce((sum, arr) => sum + arr.length, 0);
    this.counterTargets.forEach(c => { c.textContent = count; });
    if (count > 0) {
      this.element.setAttribute("data-has-selection", "");
      this.barTargets.forEach(bar => {
        bar.hidden = false;
        bar.setAttribute("data-visible", "");
      });
    } else {
      this.element.removeAttribute("data-has-selection");
      this.barTargets.forEach(bar => {
        bar.removeAttribute("data-visible");
        setTimeout(() => { if (!this.element.hasAttribute("data-has-selection")) bar.hidden = true; }, 300);
      });
    }
  }

  _patchToggle(url) {
    if (!url) return;
    const token = document.querySelector("meta[name='csrf-token']")?.content;
    fetch(url, {
      method: "PATCH",
      headers: { "Accept": "text/vnd.turbo-stream.html", "X-CSRF-Token": token },
    }).then(r => r.text()).then(html => {
      if (html && window.Turbo) window.Turbo.renderStreamMessage(html);
    });
  }
}
