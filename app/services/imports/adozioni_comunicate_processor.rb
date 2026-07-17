# frozen_string_literal: true

module Imports
  class AdozioniComunicateProcessor < BaseProcessor
    def process_file
      importer = nil

      parse_excel do |row, line|
        importer ||= build_importer(row)
        importer.import_row(
          codicescuola: row[:codministeriale],
          ean: row[:ean],
          titolo: row[:titolo],
          classe: row[:classe],
          sezione: row[:sezione],
          classi_sezioni: row[:"classi+sezioni"],
          alunni: row[:alunni],
          editore: row[:editore],
          descrizione_scuola: row[:descrizione],
          comune: row[:comune],
          provincia: row[:provincia]
        )
      rescue ActiveRecord::RecordInvalid, ArgumentError, KeyError => e
        add_error(e.message, line: line)
      end

      @imported_count = importer&.importate.to_i
      @updated_count = importer&.aggiornate.to_i
    end

    private

    def build_importer(row)
      anno = @metadata["anno_scolastico"].presence || row[:anno].to_s.presence
      raise ArgumentError, "anno scolastico mancante (colonna Anno o metadata)" if anno.blank?

      ::Adozioni::Comunicate::Importer.new(
        account: @account,
        anno_scolastico: anno,
        fonte: "excel",
        import_record_id: @metadata["import_record_id"]
      )
    end
  end
end
