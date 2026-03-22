module Filters
  class PropagandaFilter < Base
    module Summarized
      extend ActiveSupport::Concern

      def summary
        parts = [terms_summary, province_summary, giri_summary].compact
        parts.any? ? parts.to_sentence : "Tutte le scuole"
      end

      private

      def terms_summary
        "\"#{terms.join(', ')}\"" if terms.any?
      end

      def province_summary
        if province.any?
          province.count == 1 ? province.first : "#{province.count} province"
        end
      end

      def giri_summary
        if giro_ids.any?
          giro_ids.count == 1 ? "1 giro" : "#{giro_ids.count} giri"
        end
      end
    end
  end
end
