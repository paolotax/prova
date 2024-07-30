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

