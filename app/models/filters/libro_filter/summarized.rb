module Filters
  class LibroFilter < Base
    module Summarized
      extend ActiveSupport::Concern

      def summary
        parts = [terms_summary, editori_summary, categorie_summary, discipline_summary, classi_summary, sort_summary].compact
        parts.any? ? parts.to_sentence : "Tutti i libri"
      end

      private

      def terms_summary
        if terms.any?
          "\"#{terms.join(', ')}\""
        end
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

      def discipline_summary
        if discipline.any?
          discipline.count == 1 ? discipline.first : "#{discipline.count} discipline"
        end
      end

      def classi_summary
        if classi.any?
          classi.count == 1 ? "classe #{classi.first}" : "#{classi.count} classi"
        end
      end

      def sort_summary
        unless default_sorted_by?
          "ordinati per #{sorted_by}"
        end
      end
    end
  end
end
