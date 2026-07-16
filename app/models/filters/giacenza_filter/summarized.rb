module Filters
  class GiacenzaFilter < Base
    module Summarized
      extend ActiveSupport::Concern

      def summary
        parts = [terms_summary, stato_summary, editori_summary].compact
        parts.any? ? parts.to_sentence : "Tutte le giacenze"
      end

      private

      def terms_summary
        if terms.any?
          "\"#{terms.join(', ')}\""
        end
      end

      def stato_summary
        STATI[stato] if stato.present?
      end

      def editori_summary
        if editori.any?
          editori.count == 1 ? editori.first : "#{editori.count} editori"
        end
      end
    end
  end
end
