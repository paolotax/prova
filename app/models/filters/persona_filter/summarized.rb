module Filters
  class PersonaFilter < Base
    module Summarized
      extend ActiveSupport::Concern

      STATO_CONTATTO_LABELS = {
        "con_email" => "con email",
        "con_telefono" => "con telefono",
        "con_scuola" => "con scuola",
        "senza_scuola" => "senza scuola"
      }.freeze

      def summary
        parts = [terms_summary, ruoli_summary, classi_summary, materie_summary, stato_contatto_summary, sort_summary].compact
        parts.any? ? parts.to_sentence : "Tutti i contatti"
      end

      private

      def terms_summary
        "\"#{terms.join(', ')}\"" if terms.any?
      end

      def ruoli_summary
        if ruoli.any?
          ruoli.count == 1 ? ruoli.first : "#{ruoli.count} ruoli"
        end
      end

      def classi_summary
        if classi.any?
          classi.count == 1 ? "classe #{classi.first}" : "classi #{classi.join(', ')}"
        end
      end

      def materie_summary
        if materie.any?
          materie.count == 1 ? materie.first : "#{materie.count} materie"
        end
      end

      def stato_contatto_summary
        STATO_CONTATTO_LABELS[stato_contatto] if stato_contatto.present?
      end

      def sort_summary
        "ordinati per #{sorted_by}" unless default_sorted_by?
      end
    end
  end
end
