# frozen_string_literal: true

module Imports
  class LibriProcessor < BaseProcessor
    include ActionView::Helpers::SanitizeHelper

    protected

    def process_file
      if csv_file?
        parse_csv do |row, line|
          libro = assign_from_row(row)
          track_result(libro, line: line)
        end
      else
        parse_excel do |row, line|
          libro = assign_from_row(row)
          track_result(libro, line: line)
        end
      end
    end

    private

    def csv_file?
      file_path.to_s.end_with?('.csv')
    end

    def assign_from_row(row)
      codice_isbn = row[:codice_isbn] || row[:isbn] || row[:ean]

      libro = @account.libri.where(codice_isbn: codice_isbn).first_or_initialize
      libro.user_id ||= @user.id
      libro.codice_isbn = codice_isbn if codice_isbn.present?

      titolo = row[:titolo] || row[:descrizione]
      libro.titolo = strip_tags(titolo) if titolo.present?

      libro.prezzo = check_prezzo(row[:prezzo]) if row[:prezzo].present?
      libro.prezzo_suggerito = check_prezzo(row[:prezzo_suggerito]) if row[:prezzo_suggerito].present?

      # Assign other attributes dynamically
      assignable_keys = row.keys - [:editore, :titolo, :prezzo, :prezzo_suggerito, :categoria, :isbn, :ean]
      assignable_keys.each do |key|
        libro.send("#{key}=", row[key]) if libro.respond_to?("#{key}=")
      end

      # Handle editore (find only, don't create)
      if row[:editore].present?
        editore = Editore.find_by(editore: row[:editore])
        libro.editore = editore if editore
      end

      # Handle categoria
      # Non sovrascrivere la categoria di libri esistenti che ne hanno già una
      if row[:categoria].present?
        categoria = Categoria.resolve(row[:categoria], account: @account)
        libro.categoria = categoria if libro.new_record? || libro.categoria.nil?
      elsif libro.new_record? && libro.categoria.nil?
        libro.categoria = Categoria.resolve(nil, account: @account)
      end

      libro
    end
  end
end
