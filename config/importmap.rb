# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "https://ga.jspm.io/npm:@hotwired/stimulus@3.2.2/dist/stimulus.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin "slim-select", to: "https://ga.jspm.io/npm:slim-select@2.7.1/dist/slimselect.js"

pin_all_from "app/javascript/controllers", under: "controllers"

pin "debounce", to: "https://ga.jspm.io/npm:debounce@2.0.0/index.js"
pin "tailwindcss-stimulus-components", to: "https://ga.jspm.io/npm:tailwindcss-stimulus-components@4.0.4/dist/tailwindcss-stimulus-components.module.js"
pin "ninja-keys", to: "https://ga.jspm.io/npm:ninja-keys@1.2.2/dist/ninja-keys.js"
pin "@lit/reactive-element", to: "https://ga.jspm.io/npm:@lit/reactive-element@1.6.3/reactive-element.js"
pin "@lit/reactive-element/decorators/", to: "https://ga.jspm.io/npm:@lit/reactive-element@1.6.3/decorators/"
pin "@material/mwc-icon", to: "https://ga.jspm.io/npm:@material/mwc-icon@0.25.3/mwc-icon.js"
pin "hotkeys-js", to: "https://ga.jspm.io/npm:hotkeys-js@3.8.7/dist/hotkeys.esm.js"
pin "lit", to: "https://ga.jspm.io/npm:lit@2.2.6/index.js"
pin "lit-element/lit-element.js", to: "https://ga.jspm.io/npm:lit-element@3.3.3/lit-element.js"
pin "lit-html", to: "https://ga.jspm.io/npm:lit-html@2.8.0/lit-html.js"
pin "lit-html/directives/", to: "https://ga.jspm.io/npm:lit-html@2.8.0/directives/"
pin "lit/", to: "https://ga.jspm.io/npm:lit@2.2.6/"
pin "tslib", to: "https://ga.jspm.io/npm:tslib@2.6.2/tslib.es6.mjs"
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"
