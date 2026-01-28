module Filters
  class EntryFilter < Base
    module Summarized
      extend ActiveSupport::Concern

      def summary
        parts = []
        parts << "\"#{terms.join(', ')}\"" if terms.present?
        parts << entryable_type_label if entryable_type.present?
        parts << state_label if state.present?
        parts << "golden" if golden == "true"
        parts.join(", ")
      end

      private

      def entryable_type_label
        case entryable_type
        when "Documento" then "documenti"
        when "Appunto" then "appunti"
        when "Tappa" then "tappe"
        else entryable_type
        end
      end

      def state_label
        case state
        when "active" then "attivi"
        when "closed" then "chiusi"
        when "postponed" then "rimandati"
        else state
        end
      end
    end
  end
end
