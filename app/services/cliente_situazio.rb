class ClienteSituazio

  attr_accessor :user, :clientable, :result
  
  def initialize(clientable:, user:)  
    @clientable = clientable
    @user = user
  end

  def sql
    sql_text = <<-SQL
      SELECT users.id, libri.id, libri.codice_isbn, libri.categoria, libri.titolo, editori.editore,
        SUM(righe.quantita) FILTER (WHERE causali.movimento = 1) as uscite,
        - SUM(righe.quantita) FILTER (WHERE causali.movimento = 0) as entrate,
        COALESCE(SUM((righe.prezzo_cents - (righe.prezzo_cents * righe.sconto / 100)) * righe.quantita / 100) FILTER (WHERE causali.movimento = 1), 0)
        - COALESCE(SUM((righe.prezzo_cents - (righe.prezzo_cents * righe.sconto / 100)) * righe.quantita / 100) FILTER (WHERE causali.movimento = 0), 0) as valore

      FROM righe
        INNER JOIN libri ON righe.libro_id = libri.id
        INNER JOIN editori ON libri.editore_id = editori.id
        INNER JOIN documento_righe ON righe.id = documento_righe.riga_id
        INNER JOIN documenti ON documento_righe.documento_id = documenti.id
        INNER JOIN causali ON documenti.causale_id = causali.id
        INNER JOIN users ON users.id = documenti.user_id
        WHERE users.id = #{user.id}
        AND documenti.clientable_type = '#{clientable.class}' AND clientable_id = #{clientable.id}
        
      GROUP BY 1, 2, 3, 4, 5, 6
      ORDER BY 4, 5
    SQL

    sql_text
  end
  
  def execute
    @result = ActiveRecord::Base.connection.execute(sql).map{|row| Clienti::RiepilogoLibro.new(row)}
  end


end
