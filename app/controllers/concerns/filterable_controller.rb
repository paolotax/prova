module FilterableController
  extend ActiveSupport::Concern

  def filter(scope, filters = filter_params)
    unless scope.respond_to?(:filter_by)
      raise "
        Controller #{self.class.name} tried to filter a scope of type #{scope.class.name}.
        Scope class does not extend FilterProxy interface.
      "
    end

    scope.filter_by(**filters)
  end

  def filter_params
    raise "FilterableModel controller #{self.class.name} does not define filter_params method."
  end

  included do
    helper_method :filter_params
  end
end