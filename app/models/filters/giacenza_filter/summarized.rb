module Filters
  class GiacenzaFilter < Base
    module Summarized
      extend ActiveSupport::Concern

      def summary
        parts = [terms_summary, stati_summary, anno_summary, editori_summary, categorie_summary].compact
        parts.any? ? parts.to_sentence : "Tutte le giacenze"
      end

      private

      def terms_summary
        if terms.any?
          "\"#{terms.join(', ')}\""
        end
      end

      def stati_summary
        STATI.values_at(*stati).to_sentence if stati.any?
      end

      def anno_summary
        "anno #{anno}" if anno != Date.current.year
      end

      def editori_summary
        if editori.any?
          editori.count == 1 ? editori.first : "#{editori.count} editori"
        end
      end

      def categorie_summary
        if categorie.any?
          categorie.count == 1 ? categorie.first : "#{categorie.count} categorie"
        end
      end
    end
  end
end
