# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin "el-transition", to: "https://ga.jspm.io/npm:el-transition@0.0.7/index.js"
pin "slim-select", to: "https://ga.jspm.io/npm:slim-select@2.7.1/dist/slimselect.js"

pin_all_from "app/javascript/controllers", under: "controllers"

pin "debounce", to: "https://ga.jspm.io/npm:debounce@2.0.0/index.js"
