RailsDesigner.configure do |config|
  # Configure when the compents library preview should be enabled.
  # The default is `false`.
  config.preview_enabled = Rails.env.development?

  # Hide the feedback button in the bottom-left of the navigation.
  # The default is `false`.
  config.disable_feedback_buttons = false

  # Set an alternative base controller for the Rails Designer library.
  # Defaults to `ApplicationController`.
  # config.base_controller = "BaseController"

  # Enable or disable font-smoothing/anti-aliasing in the Library Preview.
  # This is to make sure the preview matches your app's settings.
  config.enable_antialiasing_in_library_preview = true

  # # Rails Designer's Library "chrome" defaults to “light” mode.
  # Uncomment the line below to switch to "dark" mode:
  # config.theme = "dark"
  # Note: components are optimized for “light mode” unless specified otherwise.

  # Enables (optional) appended actions after running the component generator.
  # Actions depend on the component, eg. inject a `turbo-frame` tag into the
  # application.html.erb. Default is false.
  config.post_generator_actions = true

  # Set the Rails Designer helpers.
  # Default is an empty array, meaning no Rails Designer helpers will be available.
  # See the docs for all the details: https://railsdesigner.com/docs/helpers/.
  config.view_helpers = ["component", "stream_notification", "string_to_color", "label_for"]

  # Set one of Tailwind CSS colors as your primary- and gray color.
  # The default primary color is `sky`. The default gray color is `gray`.
  #
  # See all the options in the Tailwind CSS docs:
  # https://tailwindcss.com/docs/customizing-colors
  #
  # config.primary_color = "sky"
  # config.gray_color = "gray"

  # Set a different destination directory for the ViewComponents.
  # The default is `app/components`.
  #
  # config.components_destination_directory = "app/views/components"

  # Set the module for your components. Useful when the components need to be
  # stored under a specific module, ie. `RailsDesigner`. Make sure this matches
  # the `config.components_destination_directory` value, eg. when the
  # destination is `app/views/components/rails_designer`
  # The `component_module_name` should be `RailsDesigner`. The default is nil.
  #
  # config.component_module_name = "RailsDesigner"

  # Set a different parent class for your components.
  # The default is `ViewComponent::Base` (or `ApplicationComponent` when present).
  #
  # config.component_base_class = "MyBaseComponent"

  # Set a different destination directory for the Stimulus controllers.
  # The default is `app/javascript/controllers`.
  #
  # config.stimulus_controller_destination_directory = "frontend/controllers"

  # Set a different parent controller for the Stimulus controllers.
  #
  # config.stimulus_controller_parent_controller = "ApplicationController"
  # config.stimulus_controller_parent_module_name = "./application_controller"
end
