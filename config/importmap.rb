# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "https://ga.jspm.io/npm:@hotwired/stimulus@3.2.2/dist/stimulus.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin "el-transition", to: "https://ga.jspm.io/npm:el-transition@0.0.7/index.js"
pin "slim-select", to: "https://ga.jspm.io/npm:slim-select@2.7.1/dist/slimselect.js"

pin_all_from "app/javascript/controllers", under: "controllers"

pin "debounce", to: "https://ga.jspm.io/npm:debounce@2.0.0/index.js"
pin "tailwindcss-stimulus-components", to: "https://ga.jspm.io/npm:tailwindcss-stimulus-components@4.0.4/dist/tailwindcss-stimulus-components.module.js"
pin "flowbite", to: "https://ga.jspm.io/npm:flowbite@2.2.1/lib/esm/index.js"
pin "@popperjs/core", to: "https://ga.jspm.io/npm:@popperjs/core@2.11.8/lib/index.js"
