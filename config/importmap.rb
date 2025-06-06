# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "@hotwired--stimulus.js" # @3.2.2
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"

pin_all_from "app/javascript/controllers/helpers", under: "helpers"
pin_all_from "app/javascript/controllers", under: "controllers"


pin "debounce", to: "https://ga.jspm.io/npm:debounce@2.0.0/index.js"

pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"

pin "stimulus-clipboard" # @4.0.1
pin "tailwindcss-stimulus-components" # @4.0.4
pin "stimulus-checkbox-select-all" # @5.3.0
pin "@stimulus-components/reveal", to: "@stimulus-components--reveal.js" # @5.0.0


#pin "floating-ui", to: "https://cdn.jsdelivr.net/npm/@floating-ui/dom@1.5.4/+esm", preload: true

pin_all_from "app/assets/javascripts/controllers/helpers", under: "helpers", to: "controllers/helpers"
pin "@stimulus-components/sortable", to: "@stimulus-components--sortable.js" # @5.0.1
pin "sortablejs" # @1.15.2
pin "@rails/request.js", to: "@rails--request.js.js" # @0.0.8
pin "floating-ui", to: "https://cdn.jsdelivr.net/npm/@floating-ui/dom@1.6.7/+esm", preload: true
pin "@stimulus-components/scroll-to", to: "@stimulus-components--scroll-to.js" # @5.0.1

pin "ahoy", to: "ahoy.js"
pin "mapkick/bundle", to: "mapkick--bundle.js" # @0.2.6


pin "@hotwired/hotwire-native-bridge", to: "@hotwired--hotwire-native-bridge.js" # @1.0.0
pin "rails_request", to: "https://cdn.jsdelivr.net/npm/@rails/request.js@0.0.6/+esm", preload: true

# CodeMirror
pin "@codemirror/state", to: "https://cdn.jsdelivr.net/npm/@codemirror/state@6.4.0/+esm"
pin "@codemirror/view", to: "https://cdn.jsdelivr.net/npm/@codemirror/view@6.24.0/+esm"
pin "@codemirror/commands", to: "https://cdn.jsdelivr.net/npm/@codemirror/commands@6.3.0/+esm"
pin "@codemirror/language", to: "https://cdn.jsdelivr.net/npm/@codemirror/language@6.10.0/+esm"
pin "@codemirror/lang-sql", to: "https://cdn.jsdelivr.net/npm/@codemirror/lang-sql@6.5.4/+esm"
pin "@codemirror/theme-one-dark", to: "https://cdn.jsdelivr.net/npm/@codemirror/theme-one-dark@6.1.2/+esm"
