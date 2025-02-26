import { Turbo } from "@hotwired/turbo-rails";
import { Template } from "./confirm_modal/template.js";

// Setup:
// Add this file into your application.js, eg.
// `import "./lib/confirm_modal.js"`
//
// Usage:
// ```ruby
//  data: {
//    turbo_method: "delete",
//    turbo_confirm: "Really delete this filter?",
//    turbo_confirm_confirm_label: "Yes, put it in the shredder!",
//    turbo_confirm_cancel_label: "Oops, no go back…",
//  }
// ```
//
function insertConfirmModal(message, element) {
  
  // aggiunta da me
  const button = element.querySelector("button");
  
  const theme = button.dataset.turboConfirmTheme || "light";
  const cancelLabel = button.dataset.turboConfirmCancelLabel || "Annulla";
  const confirmLabel = button.dataset.turboConfirmConfirmLabel || "Conferma";
  
  const template = new Template({theme: theme, message: message, cancelLabel: cancelLabel, confirmLabel: confirmLabel});

  document.body.insertAdjacentHTML('beforeend', template.render());
  document.activeElement.blur();

  return document.getElementById("confirm-modal");
}

Turbo.setConfirmMethod((message, element) => {
  const dialog = insertConfirmModal(message, element);

  return new Promise((resolve) => {
    dialog.querySelector("[data-behavior='cancel']").addEventListener("click", () => {
      dialog.remove();

      resolve(false);
    }, { once: true })
    dialog.querySelector("[data-behavior='commit']").addEventListener("click", () => {
      dialog.remove();

      resolve(true);
    }, { once: true })
  })
})
