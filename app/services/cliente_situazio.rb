class ClienteSituazio

  #attr_accessor :user, :clientable_id, :clientable_type, :result
  
  def initialize(clientable:, user:)  
    @clientable = clientable
    @user = user
  end

  def sql
    sql_text = <<-SQL
      SELECT users.id, libri.titolo, libri.codice_isbn, documenti.clientable_type, documenti.clientable_id, causali.causale, documenti.status,
        SUM(righe.quantita) FILTER (WHERE causali.movimento = 1) as uscite,
        - SUM(righe.quantita) FILTER (WHERE causali.movimento = 0) as entrate
      FROM righe
        INNER JOIN libri ON righe.libro_id = libri.id
        INNER JOIN documento_righe ON righe.id = documento_righe.riga_id
        INNER JOIN documenti ON documento_righe.documento_id = documenti.id
        INNER JOIN causali ON documenti.causale_id = causali.id
        INNER JOIN users ON users.id = documenti.user_id
        WHERE users.id = #{@user.id}
        AND clientable_type = '#{@clientable.class}' AND clientable_id = #{@clientable.id}
        
      GROUP BY 1, 2, 3, 4, 5, 6, 7
      ORDER BY 1, 2
    SQL

    sql_text
  end
  
  def execute
    @result = ActiveRecord::Base.connection.execute(sql)
  end


end
