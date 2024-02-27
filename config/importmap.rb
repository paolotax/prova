# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "@hotwired--stimulus.js" # @3.2.2
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true

pin_all_from "app/javascript/controllers", under: "controllers"

pin "debounce", to: "https://ga.jspm.io/npm:debounce@2.0.0/index.js"
pin "tailwindcss-stimulus-components", to: "https://ga.jspm.io/npm:tailwindcss-stimulus-components@4.0.4/dist/tailwindcss-stimulus-components.module.js"
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"
pin "cropperjs" # @2.0.0
pin "@cropper/element", to: "@cropper--element.js" # @2.0.0
pin "@cropper/element-canvas", to: "@cropper--element-canvas.js" # @2.0.0
pin "@cropper/element-crosshair", to: "@cropper--element-crosshair.js" # @2.0.0
pin "@cropper/element-grid", to: "@cropper--element-grid.js" # @2.0.0
pin "@cropper/element-handle", to: "@cropper--element-handle.js" # @2.0.0
pin "@cropper/element-image", to: "@cropper--element-image.js" # @2.0.0
pin "@cropper/element-selection", to: "@cropper--element-selection.js" # @2.0.0
pin "@cropper/element-shade", to: "@cropper--element-shade.js" # @2.0.0
pin "@cropper/element-viewer", to: "@cropper--element-viewer.js" # @2.0.0
pin "@cropper/elements", to: "@cropper--elements.js" # @2.0.0
pin "@cropper/utils", to: "@cropper--utils.js" # @2.0.0
pin "stimulus-clipboard" # @4.0.1
