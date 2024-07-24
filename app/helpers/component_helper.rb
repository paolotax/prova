module ComponentHelper
  # This helper allows to render components in a more terse way.
  # Instead of `<%= render(ExampleComponent.new(title: "Hello World!")) %>`
  # write `<%= component "example", title: "Hello World!" %>`,
  # and for nested components: `<%= component "nested/example", title: "Hello World!" %>`
  #
  def component(name, *args, **kwargs, &block)
    component = "#{name.to_s.camelize}Component".safe_constantize

    render(component.new(*args, **kwargs), &block)
  end
end
