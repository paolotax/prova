// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"


import "trix"
import "@rails/actiontext"

import "mapkick/bundle"


console.log("Hello from application.js")



// Turbo.setProgressBarDelay(1)

// window.addEventListener("turbo:frame-render", (e) => {
//     console.log("turbo:frame-render", e)
// })
  
// window.addEventListener("turbo:frame-load", (e) => {
//     console.log("turbo:frame-load", e)
// })

import {Turbo} from "@hotwired/turbo-rails"

Turbo.StreamActions.redirect =  function() {
    Turbo.visit(this.target);
};

// document.addEventListener('turbo:frame-load', function(event) {
//     if (event.target.id === "search_results") {
//         // Trova e modifica i link esterni al turbo_frame
//         var externalLinkContainer = document.getElementById("button-excel-libri");
//         var externalLink1 = externalLinkContainer.querySelector("a");

//         var params = window.location.search;

//         // Modifica gli href dei link esterni
//         if (externalLink1) {
//             externalLink1.href = "/libri.xlsx" + params;
//         }
//     }
// });