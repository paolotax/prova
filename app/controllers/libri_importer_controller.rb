# frozen_string_literal: true

# Temporary: only export_confezioni remains until migrated to ImportsController
class LibriImporterController < ApplicationController
  def export_confezioni
    sql = <<-SQL
      SELECT
        confezioni.codice_isbn as confezione_isbn,
        confezioni.titolo as confezione_titolo,
        fascicoli.codice_isbn as fascicolo_isbn,
        fascicoli.titolo as fascicolo_titolo,
        COALESCE(confezione_righe.row_order, 0) as row_order
      FROM confezione_righe
        INNER JOIN libri as confezioni ON confezioni.id = confezione_righe.confezione_id
        INNER JOIN libri as fascicoli ON fascicoli.id = confezione_righe.fascicolo_id
      WHERE confezioni.user_id = #{current_user.id}
      ORDER BY confezioni.codice_isbn, COALESCE(confezione_righe.row_order, 999999)
    SQL

    @confezioni = ActiveRecord::Base.connection.execute(sql)

    respond_to do |format|
      format.xlsx
    end
  end
end
