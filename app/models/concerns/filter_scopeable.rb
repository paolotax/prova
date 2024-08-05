module FilterScopeable
  extend ActiveSupport::Concern

  def filter_scope(name, block)
    define_method(name) do |filter_value|
      return self if filter_value.blank?

      instance_exec(filter_value, &block)
    end
  end
end