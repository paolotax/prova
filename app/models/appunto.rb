# == Schema Information
#
# Table name: appunti
#
#  id                 :integer          not null, primary key
#  import_scuola_id   :integer
#  user_id            :integer          not null
#  import_adozione_id :integer
#  nome               :string
#  body               :text
#  email              :string
#  telefono           :string
#  stato              :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  completed_at       :datetime
#  team               :string
#  classe_id          :integer
#  voice_note_id      :integer
#  active             :boolean
#
# Indexes
#
#  index_appunti_on_classe_id           (classe_id)
#  index_appunti_on_import_adozione_id  (import_adozione_id)
#  index_appunti_on_import_scuola_id    (import_scuola_id)
#  index_appunti_on_user_id             (user_id)
#  index_appunti_on_voice_note_id       (voice_note_id)
#

class Appunto < ApplicationRecord
  
  belongs_to :import_scuola, required: false
  belongs_to :user
  belongs_to :import_adozione, required: false
  belongs_to :classe, class_name: "Views::Classe", optional: true

  has_one_attached :image
  has_many_attached :attachments
  has_rich_text :content

  has_many :tappe, as: :tappable

  belongs_to :voice_note, optional: true


  include PgSearch::Model

  search_fields =  [ :nome, :body, :email, :telefono, :stato]

  pg_search_scope :search_all_word, 
                      against: search_fields,
                      associated_against: {
                        import_scuola:   [:CODICESCUOLA, :DENOMINAZIONESCUOLA, :DESCRIZIONECOMUNE],
                        import_adozione: [:CODICESCUOLA, :CODICEISBN, :EDITORE],
                        rich_text_content: [:body],
                        attachments_blobs: [:filename]
                      },
                      using: {
                        tsearch: { any_word: false, prefix: true }
                      }

  include Searchable

  search_on :nome, :body, :email, :telefono, :stato, 
            import_adozione: [:CODICESCUOLA, :CODICEISBN, :EDITORE],
            rich_text_content: [:body],
            attachments_blobs: [:filename], 
            import_scuola: [:CODICESCUOLA, :DENOMINAZIONESCUOLA, :DESCRIZIONECOMUNE, :DESCRIZIONECARATTERISTICASCUOLA, :DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA, :CODICEISTITUTORIFERIMENTO, :DENOMINAZIONEISTITUTORIFERIMENTO]
  
  extend FilterableModel
  class << self
    def filter_proxy = Filters::AppuntoFilterProxy
  end

  STATO_APPUNTI = ["da fare", "in evidenza", "in settimana", "in visione", "da pagare", "completato", "archiviato"]  
  
  FILTERS = [ 
    ["Tutti",  "/appunti"], 
    ["Oggi",   "/appunti?filter=oggi"], 
    ["Domani", "/appunti?filter=domani"],
    ["In sospeso", "/appunti?stato=in_sospeso"],
    ["In settimana", "/appunti?stato=in_settimana"],
    ["Non archiviati", "/appunti?filter=non_archiviati"],
    ["Archiviati", "/appunti?stato=archiviato"],
  ]

  
  after_initialize :set_default_stato, :if => :new_record?
  
  def set_default_stato
    self.stato ||= "da fare"
  end

  scope :dell_utente, ->(user) { where(user_id: user.id) }

  scope :non_saggi, -> { where.not(nome: ["saggio", "seguito", "kit"]) }
  
  scope :da_fare, -> { where(stato: "da fare").non_saggi }
  scope :in_evidenza, -> { where(stato: "in evidenza").non_saggi }
  scope :in_settimana, -> { where(stato: "in settimana").non_saggi }
  scope :da_pagare, -> { where(stato: "da pagare").non_saggi }
  scope :in_visione, -> { where(stato: "in visione").non_saggi }
  scope :completati, -> { where(stato: "completato").non_saggi }
  
  scope :archiviati, -> { where(stato: "archiviato").non_saggi }
 
  scope :da_completare, -> { where(stato: ["da fare", "in evidenza", "in settimana"]).non_saggi }
  scope :in_sospeso, -> { where(stato: ["in visione", "da pagare"]).non_saggi } 
  scope :non_archiviati, -> { where.not(stato: ["archiviato", "completato"]).non_saggi }

  # non includono clienti REFACTOR appunto clientable
  scope :nel_baule_di_oggi, -> { where(import_scuola_id: Current.user.tappe.di_oggi.where(tappable_type: "ImportScuola").pluck(:tappable_id)) }  
  scope :nel_baule_di_domani, -> { where(import_scuola_id: Current.user.tappe.di_domani.where(tappable_type: "ImportScuola").pluck(:tappable_id)) }  
  scope :nel_baule_del_giorno, ->(day) { where(import_scuola_id: Current.user.tappe.del_giorno(day).where(tappable_type: "ImportScuola").pluck(:tappable_id)) }  


  scope :saggi, -> { where(nome: "saggio").where.not(import_adozione_id: nil) }
  scope :seguiti, -> { where(nome: "seguito").where.not(import_adozione_id: nil) }
  scope :kit, -> { where(nome: "kit").where.not(import_adozione_id: nil) }
  scope :ssk, -> { where(nome: ["saggio", "seguito", "kit"]).where.not(import_adozione_id: nil) }
  

  def self.ransackable_attributes(auth_object = nil)
    %w[nome body]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[nome body]
  end

  def scuola 
    import_scuola
  end
  
  def content_to_s
    content.to_s.gsub('<div class="trix-content">', "").gsub('</div>', "").gsub('<div>', "").gsub('</br>', "").gsub('<p>', "").gsub('</p>', "").gsub('<div>', "").gsub('</div>', "").gsub('<br/>', "").gsub('</br/>', "").gsub('<p/>', "").gsub('</p/>', "").gsub('<div/>', "").gsub('</div/>', "").gsub('<br />', "").gsub('</br />', "").gsub('<p />', "").gsub('</p />', "").gsub('<div />', "").gsub('</div />', "")
  end
  
  def nome_e_classe
    if nome.present? && classe.present?
      "#{nome} - #{classe.to_combobox_display}"
    elsif nome.present?
      nome
    elsif classe.present?
      classe.to_combobox_display
    else
      ""
    end
  end
  
  def image_as_thumbnail
    return unless image.content_type.in?(%w[image/jpeg image/png image/jpg image/gif image/webp])
    self.image.variant(resize_to_limit: [300, 300]).processed
  end


  def appunto_attachment(index)
    target = attachments[index]
    return unless attachments.attached?

    if target.image?
      target.variant(resize_to_limit: [200, 200]).processed
    elsif target.video?
      target.variant(resize_to_limit: [200, 200]).processed
    end
  end

  def representables_attachments
    representables_attachments = []
    if self.attachments.attached?
      self.attachments.each do |att|
        if att.representable?
          representables_attachments << att
        end   
      end
    end
    representables_attachments
  end

  def file_attachments
    file_attachments = []
    if self.attachments.attached?
      self.attachments.each do |att|
        if !att.representable?
          file_attachments << att
        end   
      end
    end
    file_attachments
  end

  def self.nel_baule
    appunti_scuole_di_oggi =  Appunto.where(import_scuola_id: Tappa.di_oggi.where(tappable_type: "ImportScuola").pluck(:tappable_id))
    #appunti_adozioni_di_oggi = Appunto.where(import_adozione_id: Tappa.di_oggi.where(tappable_type: "ImportAdozione").pluck(:tappable_id)) 
    #appunti_scuole_di_oggi.or(appunti_adozioni_di_oggi)
  end

  def is_saggio?
    nome == "saggio" && self.import_adozione.present?
  end

  def is_seguito?
    nome == "seguito" && self.import_adozione.present?
  end

  def is_kit?
    nome == "seguito" && self.import_adozione.present?
  end

  def is_ssk?
    ["saggio", "seguito", "kit"].include?(nome) && self.import_adozione.present?
  end

end
