// Import and register all your controllers from the importmap under controllers/*


import { application } from "controllers/application"

// Eager load all controllers defined in the import map under controllers/**/*_controller
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

// Lazy load controllers as they appear in the DOM (remember not to preload controllers in import map!)
// import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"
// lazyLoadControllersFrom("controllers", application)


// Ricarica la mappa dopo ogni aggiornamento Turbo
document.addEventListener("turbo:frame-load", () => {
    const mapControllers = application.getControllerForElementAndIdentifier(
      document.querySelector('[data-controller="mappa-directions"]'),
      "map"
    );
    if (mapControllers) {
        console.log("turbo:frame-load")
      mapControllers.initMap();
    }
  });
  
  document.addEventListener("turbo:load", () => {
    const mapControllers = application.getControllerForElementAndIdentifier(
      document.querySelector('[data-controller="mappa-directions"]'),
      "map"
    );
    if (mapControllers) {
        console.log("turbo:load")
      mapControllers.initMap();
    }
  });

  


