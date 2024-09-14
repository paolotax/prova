class LibroInfo
  
  attr_accessor :ordini, :vendite, :carichi, :adozioni
  
  def initialize(libro:, user:)
    @libro = libro
    @user = user
    
    situazione_magazzino
    count_adozioni
  end

  # causale.rb 
  # enum tipo_movimento: { ordine: 0, vendita: 1, carico: 2 } 
  # enum movimento: { entrata: 0, uscita: 1 }

  # enum :status, [:ordine, :in_consegna, :da_pagare, :da_registrare, :corrispettivi, :fattura]
  # enum :tipo_pagamento, [:contanti, :assegno, :bonifico, :bancomat, :carta_di_credito, :paypal, :satispay, :cedole]
  
  def situazione_magazzino    
    
    query = <<-SQL
      SELECT users.id, libri.titolo, libri.codice_isbn,
          (COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 1 and (causali.tipo_movimento = 0 and documenti.status = 0)), 0) -
          COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 0 and (causali.tipo_movimento = 0 and documenti.status = 0)), 0)) as ordini,
          
          (COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 1 and (causali.tipo_movimento = 1 or (causali.tipo_movimento = 0 and documenti.status <> 0))), 0) -
          COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 0 and (causali.tipo_movimento = 1 or (causali.tipo_movimento = 0 and documenti.status <> 0))), 0)) as vendite,
          
          (COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 0 and causali.tipo_movimento = 2), 0) -
          COALESCE(SUM(righe.quantita) FILTER (WHERE causali.movimento = 1 and causali.tipo_movimento = 2), 0)) as carichi
      
      FROM righe
      INNER JOIN libri ON righe.libro_id = libri.id
      INNER JOIN documento_righe ON righe.id = documento_righe.riga_id
      INNER JOIN documenti ON documento_righe.documento_id = documenti.id
      INNER JOIN causali ON documenti.causale_id = causali.id
      INNER JOIN users ON users.id = documenti.user_id
      WHERE users.id = #{Current.user.id} AND libri.id = #{@libro.id}
      GROUP BY 1, 2, 3
    SQL

    result = ActiveRecord::Base.connection.execute(query)
    if result.ntuples == 0
      @ordini = 0
      @vendite = 0
      @carichi = 0
    else
      @ordini = result[0]['ordini']
      @vendite = result[0]['vendite']
      @carichi = result[0]['carichi']
    end
  end

  
  
  def count_adozioni
    @adozioni = @user.mie_adozioni.where(CODICEISBN: @libro.codice_isbn, DAACQUIST: "Si").count
  end

end