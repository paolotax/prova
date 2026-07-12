# frozen_string_literal: true

Rails.application.config.assets.version = "1.0"

# Propshaft does not add vendor/assets automatically. Third-party browser assets
# committed to the repository (currently CodeMirror) must be explicit load paths.
Rails.application.config.assets.paths << Rails.root.join("vendor/assets/javascripts")
Rails.application.config.assets.paths << Rails.root.join("vendor/assets/stylesheets")
