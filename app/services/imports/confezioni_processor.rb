# frozen_string_literal: true

module Imports
  class ConfezioniProcessor < BaseProcessor
    protected

    def process_file
      parse_excel do |row, line|
        process_confezione_row(row, line)
      end
    end

    private

    def process_confezione_row(row, line)
      confezione_isbn = row[:confezione_isbn]
      fascicolo_isbn = row[:fascicolo_isbn]
      row_order = row[:row_order].to_i

      confezione = Libro.find_by(codice_isbn: confezione_isbn, user_id: @user.id)
      fascicolo = Libro.find_by(codice_isbn: fascicolo_isbn, user_id: @user.id)

      unless confezione
        add_error("Libro confezione con ISBN #{confezione_isbn} non trovato", line: line)
        return
      end

      unless fascicolo
        add_error("Libro fascicolo con ISBN #{fascicolo_isbn} non trovato", line: line)
        return
      end

      existing = ConfezioneRiga.find_by(
        confezione_id: confezione.id,
        fascicolo_id: fascicolo.id
      )

      if existing
        if existing.row_order != row_order
          existing.update_column(:row_order, row_order)
          @updated_count += 1
        end
      else
        confezione_riga = ConfezioneRiga.new(
          confezione_id: confezione.id,
          fascicolo_id: fascicolo.id
        )

        if confezione_riga.save
          confezione_riga.update_column(:row_order, row_order) if row_order.present?
          @created_count += 1
        else
          add_error(confezione_riga.errors.full_messages.join(", "), line: line)
        end
      end
    end
  end
end
