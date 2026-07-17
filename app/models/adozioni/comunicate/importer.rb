module Adozioni
  module Comunicate
    class Importer
      attr_reader :importate, :aggiornate, :errori

      def initialize(account:, anno_scolastico:, fonte:, editore: nil, import_record_id: nil)
        @account = account
        @anno_scolastico = anno_scolastico.to_s
        @fonte = fonte
        @editore = editore
        @import_record_id = import_record_id
        @importate = 0
        @aggiornate = 0
        @errori = []
        @record_ids = []
      end

      def import_rows(rows)
        rows.each_with_index do |row, indice|
          import_row(row.to_h.symbolize_keys)
        rescue ActiveRecord::RecordInvalid, ArgumentError, KeyError => e
          @errori << "Riga #{indice + 1}: #{e.message}"
        end
        self
      end

      def import_row(attrs)
        anno_corso, sezioni = estrai_anno_corso_e_sezioni(attrs)

        comunicata = Comunicata.where(
          account: @account,
          anno_scolastico: @anno_scolastico,
          codicescuola: attrs.fetch(:codicescuola).to_s.strip.upcase,
          ean: Comunicata.normalizza_ean(attrs.fetch(:ean)),
          anno_corso: anno_corso,
          sezioni: sezioni
        ).first_or_initialize

        nuova = comunicata.new_record?
        comunicata.assign_attributes(
          alunni: attrs.fetch(:alunni).to_i,
          fonte: @fonte,
          import_record_id: @import_record_id || comunicata.import_record_id,
          titolo: attrs[:titolo].presence || comunicata.titolo,
          editore: attrs[:editore].presence || @editore || comunicata.editore,
          descrizione_scuola: attrs[:descrizione_scuola].presence || comunicata.descrizione_scuola,
          comune: attrs[:comune].presence || comunicata.comune,
          provincia: attrs[:provincia].presence || comunicata.provincia
        )
        comunicata.save!
        Matcher.new(comunicata).match!

        nuova ? @importate += 1 : @aggiornate += 1
        @record_ids << comunicata.id
        comunicata
      end

      def riepilogo
        righe = Comunicata.where(id: @record_ids)
        {
          importate: @importate,
          aggiornate: @aggiornate,
          errori: @errori,
          matched: righe.matched.count,
          discrepanze: righe.discrepanze.map do |riga|
            riga.slice(:codicescuola, :descrizione_scuola, :ean, :titolo,
                       :anno_corso, :sezioni, :alunni, :stato_match).symbolize_keys
          end
        }
      end

      private

      # Accetta classe/sezione separati (chiavi :classe o :anno_corso, :sezione o
      # :sezioni) oppure il campo combinato :classi_sezioni ("3B", "3 B", "3/B").
      def estrai_anno_corso_e_sezioni(attrs)
        anno_corso = attrs[:classe].presence || attrs[:anno_corso]
        sezioni = attrs[:sezioni].presence || attrs[:sezione]

        if anno_corso.blank? && attrs[:classi_sezioni].present?
          anno_corso, sezioni = split_classi_sezioni(attrs[:classi_sezioni])
        end

        anno_corso = anno_corso.is_a?(Numeric) ? anno_corso.to_i.to_s : anno_corso.to_s.strip
        raise ArgumentError, "classe/anno corso mancante" if anno_corso.blank?

        sezioni = sezioni.to_s.split(",").map { |s| s.strip.upcase }.reject(&:empty?).join(",")
        [anno_corso, sezioni]
      end

      def split_classi_sezioni(value)
        match = value.to_s.strip.match(%r{\A(\d)\s*[-/_ ]*\s*([A-Za-z].*)\z})
        match ? [match[1], match[2]] : [value.to_s.strip, ""]
      end
    end
  end
end
