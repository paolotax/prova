# == Schema Information
#
# Table name: adozioni
#
#  id                 :bigint           not null, primary key
#  importo_cents      :integer
#  note               :text
#  numero_copie       :integer
#  numero_sezioni     :integer
#  prezzo_cents       :integer
#  stato_adozione     :string
#  team               :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  classe_id          :bigint
#  import_adozione_id :bigint           not null
#  libro_id           :bigint           not null
#  user_id            :bigint           not null
#
# Indexes
#
#  index_adozioni_on_classe_id           (classe_id)
#  index_adozioni_on_import_adozione_id  (import_adozione_id)
#  index_adozioni_on_libro_id            (libro_id)
#  index_adozioni_on_user_id             (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (import_adozione_id => import_adozioni.id)
#  fk_rails_...  (libro_id => libri.id)
#  fk_rails_...  (user_id => users.id)
#
class Adozione < ApplicationRecord
  belongs_to :user
  belongs_to :import_adozione
  
  belongs_to :libro, optional: true

  #belongs_to :classe, class_name: "Views::Classe", query_constraints: [:CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO, :DISCIPLINA]

  belongs_to :classe, class_name: "Views::Classe", optional: true

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
