class LibroInfo 
  
  def initialize(libro:, user:)
    @libro = libro
    @user = user
  end

  def situazione_magazzino    
    query = <<-SQL
      SELECT users.id, libri.titolo, libri.codice_isbn,
          (COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 1 and causali.tipo_movimento = 0), 0) -
          COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 0 and causali.tipo_movimento = 0), 0)) as ordini,
          (COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 1 and causali.tipo_movimento = 1), 0) -
          COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 0 and causali.tipo_movimento = 1), 0)) as vendite,
          (COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 0 and causali.tipo_movimento = 2), 0) -
          COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 1 and causali.tipo_movimento = 2), 0)) as carichi
      FROM righe
      INNER JOIN libri ON righe.libro_id = libri.id
      INNER JOIN documento_righe ON righe.id = documento_righe.riga_id
      INNER JOIN documenti ON documento_righe.documento_id = documenti.id
      INNER JOIN causali ON documenti.causale_id = causali.id
      INNER JOIN users ON users.id = documenti.user_id
      WHERE users.id = #{Current.user.id} AND libri.id = #{@libro_id}
      GROUP BY 1, 2, 3
    SQL
    result = ActiveRecord::Base.connection.execute(query)
    result
  end

  def adozioni
    @user.mie_adozioni.where(CODICEISBN: @libro.codice_isbn, DAACQUIST: "Si")
  end

end