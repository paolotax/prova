# == Schema Information
#
# Table name: adozioni
#
#  id                 :bigint           not null, primary key
#  consegnato_il      :datetime
#  importo_cents      :integer
#  note               :text
#  numero_copie       :integer
#  numero_documento   :integer
#  numero_sezioni     :integer
#  pagato_il          :datetime
#  prezzo_cents       :integer
#  stato_adozione     :string
#  status             :integer          default(0)
#  team               :string
#  tipo               :integer          default(0)
#  tipo_pagamento     :string
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
#  index_adozioni_on_status              (status)
#  index_adozioni_on_tipo                (tipo)
#  index_adozioni_on_user_id             (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (import_adozione_id => import_adozioni.id)
#  fk_rails_...  (libro_id => libri.id)
#  fk_rails_...  (user_id => users.id)
#
class Adozione < ApplicationRecord

  enum :status, [:ordine, :in_consegna, :da_pagare, :da_registrare, :corrispettivi, :fattura]
  enum :tipo, %i(adozione vendita omaggio)
  
  
  belongs_to :user  
  belongs_to :import_adozione, optional: true
  belongs_to :libro, optional: true
  belongs_to :classe, class_name: "Views::Classe", optional: true
  has_one :scuola, through: :classe, source: :import_scuola

  before_save do |a|
    a.numero_sezioni = 1 if a.numero_sezioni.nil?
    a.numero_copie = 0 if a.numero_copie.nil?
    a.prezzo_cents = 0 if a.prezzo_cents.nil?

    if a.stato_adozione.downcase[0..2] == "com"
      a.tipo = "vendita"
    elsif a.stato_adozione.downcase[0..2] == "ado"
      a.tipo = "adozione"
    else
      a.tipo = "omaggio"
    end
  end

  before_update do |a|
    a.numero_sezioni = 1 if a.numero_sezioni.nil?
    a.numero_copie = 0 if a.numero_copie.nil?
    a.prezzo_cents = 0 if a.prezzo_cents.nil?
    if a.stato_adozione.downcase[0..2] == "com"
      a.tipo = "vendita"
    elsif a.stato_adozione.downcase[0..2] == "ado"
      a.tipo = "adozione"
    else
      a.tipo = "omaggio"
    end
  end

  # return [["amica parola", 22]=>3, [...]=>2, ...]
  scope :per_libro, -> { 
    joins(:libro)        
    .select(:titolo, :libro_id)
    .select("sum(adozioni.numero_sezioni) as numero_sezioni")
    .select("sum(adozioni.numero_copie) as numero_copie")
    .select("ARRAY_AGG(adozioni.id) AS adozione_ids")
    .group(:titolo, :libro_id) 
    .order(:titolo)
  }

  scope :per_scuola, -> { 
    joins(:scuola, :classe)        
    .select('import_scuole.id, import_scuole."DENOMINAZIONESCUOLA"')
    .select("sum(adozioni.numero_sezioni) as numero_sezioni")
    .select("sum(adozioni.numero_copie) as numero_copie")
    .select("sum(adozioni.numero_copie * adozioni.prezzo_cents) as importo_cents")
    .select("ARRAY_AGG(adozioni.id) AS adozione_ids")
    .group('import_scuole.id, import_scuole."DENOMINAZIONESCUOLA"') 
    .order("import_scuole.id")
  }

  scope :per_libro_titolo, -> { 
    joins(:classe, libro: [:editore])        
    .select('CONCAT(libri.titolo, \' \', view_classi.classe) AS libro_titolo')
    .select('editori.editore AS editore')
    .select("sum(adozioni.numero_copie) as numero_copie")
    .select("sum(adozioni.numero_copie * adozioni.prezzo_cents) as importo_cents")
    .select("sum(CASE WHEN adozioni.status = 1 THEN adozioni.numero_copie ELSE 0 END) AS in_consegna")
    .select("sum(CASE WHEN adozioni.status > 1 THEN adozioni.numero_copie ELSE 0 END) AS consegnato")
    .select("sum(adozioni.numero_copie - (CASE WHEN adozioni.status = 1 THEN adozioni.numero_copie ELSE 0 END) - (CASE WHEN adozioni.status > 1 THEN adozioni.numero_copie ELSE 0 END)) as giacenza")    
    .select("ARRAY_AGG(adozioni.id) AS adozione_ids")
    .where("adozioni.numero_copie > 0")
    .group('libro_titolo, editore') 
    .order("libro_titolo")
  }

  scope :per_libro_categoria, -> { 
    joins(:libro)        
    .select('libri.categoria AS libro_categoria')
    .select("sum(adozioni.numero_sezioni) as numero_sezioni")
    .select("ARRAY_AGG(adozioni.id) AS adozione_ids")
    .group('libro_categoria') 
    .order("libro_categoria")
  }

  scope :pre_adozioni, -> { where(stato_adozione: ['adotta', "adottano"]) }
  scope :vendite,  -> { where(stato_adozione: ['compra', "comprano"]) }
  scope :saggi,    -> { where(stato_adozione: ['saggio', "saggio"]) }

  include Searchable

  search_on :stato_adozione, 
            :team, 
            :note,
            :tipo_pagamento,
            classe: [:classe, :sezione, :combinazione], 
            libro:  [:categoria, :titolo, :disciplina],
            scuola: [:DENOMINAZIONESCUOLA, :DESCRIZIONECOMUNE, :DESCRIZIONECARATTERISTICASCUOLA, :DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA]

    
  def self.stato_adozione
    where.not(stato_adozione:[ nil, ""]).order(:stato_adozione).distinct.pluck(:stato_adozione).compact
  end

  # ora così poi devo vedere come funziona money-rails
  def prezzo
    prezzo_cents.to_f / 100
  end

  def prezzo=(prezzo)
    self.prezzo_cents = (prezzo.to_f * 100).to_i
  end

  def importo
    self.prezzo_cents.to_f * self.numero_copie / 100
  end

  #attr_accessor :titolo

  def titolo=(titolo)
    libro = Current.user.libri.find_or_create_by(titolo: new_libro)
    libro.prezzo_in_cents = 0
    libro.save
    self.libro = libro
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

  def nome_scuola 
    self.scuola&.scuola || self.import_adozione&.scuola
  end

  def citta 
    self.classe&.import_scuola&.citta || self.import_adozione&.citta
  end
  
  def titolo_libro
    return if self.libro.nil?

    if self.libro.categoria && self.libro.categoria.downcase == "vacanze"
      "#{self.libro.titolo} #{self.classe.classe}"
    else
      self.libro.titolo
    end

  end

  def self.per_scuola_hash     
    self.per_scuola.map do |a|
      { 
        scuola_id: a.id, 
        nome_scuola: a.DENOMINAZIONESCUOLA, 
        numero_sezioni: a.numero_sezioni,
        adozione_ids: a.adozione_ids
      }
    end
  end

  def self.per_libro_hash 
    self.per_libro.map do |a|
      { 
        libro_id: a.libro_id, 
        titolo: a.titolo, 
        numero_sezioni: a.numero_sezioni,
        numero_copie: a.numero_copie,
        adozione_ids: a.adozione_ids
      }
    end
  end
  

end
