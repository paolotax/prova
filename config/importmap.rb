# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "@hotwired--stimulus.js" # @3.2.2
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"

pin_all_from "app/javascript/controllers", under: "controllers"


pin "debounce", to: "https://ga.jspm.io/npm:debounce@2.0.0/index.js"

pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"



pin "stimulus-clipboard" # @4.0.1
pin "tailwindcss-stimulus-components" # @4.0.4
pin "stimulus-checkbox-select-all" # @5.3.0

pin "mapkick/bundle", to: "mapkick.bundle.js"
