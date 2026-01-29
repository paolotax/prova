# frozen_string_literal: true

module Imports
  class MinisterialiProcessor < BaseProcessor
    protected

    def process_file
      sql = <<-SQL
        SELECT DISTINCT
          new_adozioni.codiceisbn AS codice_isbn,
          new_adozioni.titolo,
          editori.id AS editore_id,
          new_adozioni.annocorso as classe,
          new_adozioni.disciplina,
          COALESCE(TO_NUMBER(new_adozioni.prezzo, 'FM9G999G999D99S'), 0) AS prezzo_in_cents
        FROM new_adozioni
        INNER JOIN new_scuole ON new_adozioni.codicescuola = new_scuole.codice_scuola
        INNER JOIN user_scuole ON new_scuole.import_scuola_id = user_scuole.import_scuola_id
        INNER JOIN users ON user_scuole.user_id = users.id
        INNER JOIN editori ON editori.editore = new_adozioni.editore
        INNER JOIN mandati ON mandati.editore_id = editori.id AND mandati.user_id = users.id
        WHERE
          new_adozioni.daacquist = 'Si'
        AND
          users.id = ?
      SQL

      result = ActiveRecord::Base.connection.exec_query(
        ActiveRecord::Base.sanitize_sql_array([sql, @user.id])
      )

      categoria = Categoria.find_or_create_by(nome_categoria: "Ministeriali")

      result.each.with_index(1) do |row, record_number|
        libro = assign_from_row(row, categoria)

        unless track_result(libro)
          @errors.last.prepend("Record #{record_number} (ISBN: #{row['codice_isbn']}): ")
        end
      end
    end

    private

    def assign_from_row(row, categoria)
      codice_isbn = row["codice_isbn"]

      libro = Libro.where(codice_isbn: codice_isbn, user_id: @user.id).first_or_initialize do |l|
        l.categoria_id = categoria.id
      end

      libro.categoria_id ||= categoria.id
      libro.titolo = strip_tags(row["titolo"]) if row["titolo"].present?
      libro.editore_id = row["editore_id"] if row["editore_id"].present?
      libro.classe = row["classe"] if row["classe"].present?
      libro.disciplina = row["disciplina"] if row["disciplina"].present?
      libro.prezzo_in_cents = row["prezzo_in_cents"] if row["prezzo_in_cents"].present?

      libro
    end
  end
end
