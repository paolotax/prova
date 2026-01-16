module Filters
  class Documento < Base
    module Summarized
      extend ActiveSupport::Concern

      def summary
        parts = [terms_summary, causali_summary, statuses_summary, anno_summary, consegnati_summary, pagati_summary].compact
        parts.any? ? parts.to_sentence : "Tutti i documenti"
      end

      private

      def terms_summary
        if terms.any?
          "\"#{terms.join(', ')}\""
        end
      end

      def causali_summary
        if causali.any?
          causali.count == 1 ? "causale #{causali.first}" : "#{causali.count} causali"
        end
      end

      def statuses_summary
        if statuses.any?
          statuses.count == 1 ? statuses.first : "#{statuses.count} stati"
        end
      end

      def anno_summary
        if anno.present?
          "anno #{anno}"
        end
      end

      def consegnati_summary
        "consegnati" if consegnati.present?
      end

      def pagati_summary
        "pagati" if pagati.present?
      end
    end
  end
end
