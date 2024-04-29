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
#  import_adozione_id :bigint
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
  belongs_to :import_adozione, optional: true
  
  belongs_to :libro, optional: true

  #belongs_to :classe, class_name: "Views::Classe", query_constraints: [:CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO, :DISCIPLINA]

  belongs_to :classe, class_name: "Views::Classe", optional: true

  has_one :scuola, through: :classe, source: :import_scuola


  before_save do |a|
    a.numero_sezioni = 1 if a.numero_sezioni.nil?
    a.numero_copie = 0 if a.numero_copie.nil?
  end

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
    joins(:scuola)        
    .select('import_scuole.id, import_scuole."DENOMINAZIONESCUOLA"')
    .select("sum(adozioni.numero_sezioni) as numero_sezioni")
    .select("ARRAY_AGG(adozioni.id) AS adozioni_ids")
    .group('import_scuole.id, import_scuole."DENOMINAZIONESCUOLA"') 
    .order("import_scuole.id")
  }

  include Searchable

  search_on :stato_adozione, 
            :team, 
            :note, 
            classe: [:classe, :sezione, :combinazione], 
            libro:  [:categoria, :titolo, :disciplina],
            scuola: [:DENOMINAZIONESCUOLA, :DESCRIZIONECOMUNE, :DESCRIZIONECARATTERISTICASCUOLA, :DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA]

  # search_on :nome, :body, :email, :telefono, :stato, 
  #           import_adozione: [:CODICESCUOLA, :CODICEISBN, :EDITORE],
  #           rich_text_content: [:body],
  #           attachments_blobs: [:filename], 
  #           import_scuola: [:CODICESCUOLA, :DENOMINAZIONESCUOLA, :DESCRIZIONECOMUNE, :DESCRIZIONECARATTERISTICASCUOLA, :DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA, :CODICEISTITUTORIFERIMENTO, :DENOMINAZIONEISTITUTORIFERIMENTO]
  

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

  def classe_e_sezione
    "#{self.classe&.classe} #{self.classe&.sezione&.titleize}"
  end

  # def scuola 
  #   self.classe&.import_scuola&.scuola || self.import_adozione&.scuola
  # end

  def citta 
    self.classe&.import_scuola&.citta || self.import_adozione&.citta
  end
  
  def titolo
    self.libro&.titolo
  end


  def self.per_scuola_hash 
    
    self.per_scuola.map do |a|
      { scuola_id: a.id, 
        nome_scuola: a.DENOMINAZIONESCUOLA, 
        numero_sezioni: a.numero_sezioni
      }
    end
  end

end
