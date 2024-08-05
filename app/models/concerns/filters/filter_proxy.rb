module Filters
  class FilterProxy
    extend FilterScopeable

    class << self
      # Model Class whose scope will be extended with our filter scopes module
      def query_scope
        raise "Class #{name} does not define query_scope class method."
      end

      def filter_scopes_module
        raise "Class #{name} does not define filter_scopes_module class method."
      end

      def filter_by(**filters)
        # extend model class scope with filter methods
        extended_scope = query_scope.extending(filter_scopes_module)

        # The payload for filters will be a hash. Each key will have the
        # name of a filter scope. We will map each key value pair to its
        # respective filter scope.
        filters.each do |filter_scope, filter_value|
          if filter_value.present? && extended_scope.respond_to?(filter_scope)
            extended_scope = extended_scope.send(filter_scope, filter_value)
          end
        end

        # Final relation with all filter scopes from +filters+ payload
        extended_scope
      end
    end
  end
end