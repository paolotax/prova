module Filters
  class ScuolaFilter < Base
    module Summarized
      extend ActiveSupport::Concern

      def summary
        parts = [terms_summary, comuni_summary, appunti_summary, adozioni_summary, sort_summary].compact
        parts.any? ? parts.to_sentence : "Tutte le scuole"
      end

      private

      def terms_summary
        if terms.any?
          "\"#{terms.join(', ')}\""
        end
      end

      def comuni_summary
        if comuni.any?
          comuni.count == 1 ? comuni.first : "#{comuni.count} comuni"
        end
      end

      def appunti_summary
        case appunti_filter
        when "con_appunti" then "con appunti"
        end
      end

      def adozioni_summary
        case adozioni_filter
        when "mie_adozioni" then "mie adozioni"
        when "adozioni_concorrenza" then "concorrenza"
        end
      end

      def sort_summary
        unless default_sorted_by?
          "ordinate per #{sorted_by}"
        end
      end
    end
  end
end
