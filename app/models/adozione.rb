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
#  status             :integer          default("ordine")
#  team               :string
#  tipo               :integer          default("adozione")
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
  
  FILTERS = [
    ["Adozioni", "/adozioni?tipo=adozione"], 
    ["Vendite", "/adozioni?tipo=vendita"],
    ["Oggi",    "/adozioni?giorno=oggi"], 
    ["Domani",  "/adozioni?giorno=domani"], 
    ["Ordini",  "/adozioni?status=ordine&tipo=vendita"],
    ["In consegna", "/adozioni?status=in_consegna&tipo=vendita"], 
    ["Da pagare", "/adozioni?status=da_pagare&tipo=vendita"],
    ["Corrispettivi", "/adozioni?status=corrispettivi&tipo=vendita"],
  ]

  belongs_to :user  
  belongs_to :import_adozione, optional: true
  belongs_to :libro, optional: true
  belongs_to :classe, class_name: "Views::Classe", optional: true
  has_one :scuola, through: :classe, source: :import_scuola

  before_save do |a|
    a.numero_sezioni = 1 if a.numero_sezioni.nil?
    a.numero_copie = 0 if a.numero_copie.nil?
    a.prezzo_cents = 0 if a.prezzo_cents.nil?
  end

  before_update do |a|
    a.numero_sezioni = 1 if a.numero_sezioni.nil?
    a.numero_copie = 0 if a.numero_copie.nil?
    a.prezzo_cents = 0 if a.prezzo_cents.nil?
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

  scope :incassi, -> {
    select(:tipo, :status, :tipo_pagamento, :pagato_il)
    .select("sum(adozioni.numero_copie * adozioni.prezzo_cents) as importo_cents")
    .select("ARRAY_AGG(adozioni.id) AS adozione_ids")
    .group(:tipo, :status, :tipo_pagamento, :pagato_il)
    .order(:pagato_il)
  }

  #scope :pre_adozioni, -> { where(stato_adozione: ['adotta', "adottano"]) }
  #scope :vendite,  -> { where(stato_adozione: ['compra', "comprano"]) }
  #scope :saggi,    -> { where(stato_adozione: ['saggio', "saggio"]) }

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
    prezzo_cents / 100.0
  end

  def prezzo=(prezzo)
    self.prezzo_cents = (prezzo.to_f * 100).to_i
  end

  def importo
    self.prezzo_cents.to_f * self.numero_copie / 100
  end

  #attr_accessor :titolo

  def titolo=(titolo)
    libro = Current.user.libri.find_or_create_by(titolo: titolo)
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

  def titolo_editore
    return if self.libro.nil?


    self.libro.editore&.editore


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

  def self.totale_copie
    self.sum(:numero_copie)
  end
  
  def self.totale_importo
    self.sum(&:importo)
  end

  def self.crea_documento_e_righe
    
    adozioni = Adozione.joins(:libro).where(tipo: "vendita").where.not("libri.codice_isbn IS NULL").where.not("libri.codice_isbn = ''").order(:created_at)
    # creo il documento
    
    causale = Causale.find_by(causale: "Ordine Scuola")
    
    adozioni.each do |ad|
      
      user = User.find(ad.user_id)

      numero_documento = user.documenti.where(causale: causale).maximum(:numero_documento).to_i + 1    
      classe = Views::Classe.find(ad.classe_id)
      scuola = classe.import_scuola
      libro = Libro.find(ad.libro_id)

      
      documento = user.documenti.create(
            causale: causale, 
            numero_documento: numero_documento,
            data_documento: ad.created_at, 
            clientable_type: "ImportScuola",
            clientable_id: scuola.id,
            referente: "#{ad.classe_e_sezione} - #{ad.team}",
            note: ad.note,
            status: ad.status,
            pagato_il: ad.pagato_il,
            tipo_pagamento: ad.tipo_pagamento&.downcase
          )

      documento.documento_righe.build.build_riga(libro_id: libro.id, 
        quantita: ad.numero_copie, prezzo_cents: ad.prezzo_cents, iva_cents: 0, sconto: 0)
      if documento.save
        ad.destroy
      end
    end      
  end

  def note_to_riga(adozione)
    
  end


end
