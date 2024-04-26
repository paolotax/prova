class Adozione < ApplicationRecord
  belongs_to :user
  belongs_to :import_adozione
  
  belongs_to :libro, optional: true

  # return [["amica parola", 22]=>3, [...]=>2, ...]
  scope :per_titolo, -> { 
      joins(:libro)        
      .select(:titolo, :libro_id)
      .select("sum(adozioni.numero_sezioni) as numero_sezioni")
      .select("ARRAY_AGG(adozioni.id) AS adozioni_ids")
      .group(:titolo, :libro_id) 
      .order(:titolo)
  }

  scope :per_scuola, -> { 
    joins(import_adozione: :import_scuola)        
    .select('import_scuole.id, import_scuole."DENOMINAZIONESCUOLA"')
    .select("sum(adozioni.numero_sezioni) as numero_sezioni")
    .select("ARRAY_AGG(adozioni.id) AS adozioni_ids")
    .group('import_scuole.id, import_scuole."DENOMINAZIONESCUOLA"') 
    .order("import_scuole.id")
  }


  def self.stato_adozione
    order(:stato_adozione).distinct.pluck(:stato_adozione).compact
  end

  def new_libro=(new_libro)
    libro = Current.user.libri.find_or_create_by(titolo: new_libro)
    libro.prezzo_in_cents = 0
    libro.save
    self.libro = libro
  end

  def maestre
    team.split(",").map{ |m| m.strip.split(" e ") }.flatten
  end

  
end
