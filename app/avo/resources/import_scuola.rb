class Avo::Resources::ImportScuola < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  self.search = {
    query: -> { query.ransack(CODICESCUOLA_i_contains: params[:q], m: "or").result(distinct: false) }
  }
  
  self.includes = [:direzione]

  def fields
    field :id, as: :id
    field :ANNOSCOLASTICO, as: :text
    field :AREAGEOGRAFICA, as: :text
    field :REGIONE, as: :text
    field :PROVINCIA, as: :text, filterable: true
    field :CODICEISTITUTORIFERIMENTO, as: :text
    field :DENOMINAZIONEISTITUTORIFERIMENTO, as: :text
    field :CODICESCUOLA, as: :text, filterable: true
    field :DENOMINAZIONESCUOLA, as: :text, filterable: true
    field :INDIRIZZOSCUOLA, as: :text
    field :CAPSCUOLA, as: :text, filterable: true
    field :CODICECOMUNESCUOLA, as: :text
    field :DESCRIZIONECOMUNE, as: :text, filterable: true
    field :DESCRIZIONECARATTERISTICASCUOLA, as: :text
    field :DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA, as: :text
    field :INDICAZIONESEDEDIRETTIVO, as: :text
    field :INDICAZIONESEDEOMNICOMPRENSIVO, as: :text
    field :INDIRIZZOEMAILSCUOLA, as: :text
    field :INDIRIZZOPECSCUOLA, as: :text
    field :SITOWEBSCUOLA, as: :text
    field :SEDESCOLASTICA, as: :text
    field :plessi, as: :has_many
    field :direzione, as: :belongs_to
    field :import_adozioni, as: :has_many
    field :user_scuole, as: :has_many
    field :users, as: :has_many, through: :user_scuole
    field :classi, as: :has_many
    field :appunti, as: :has_many
    field :appunti_da_completare, as: :has_many
    field :tappe, as: :has_many
    field :tipo_scuola, as: :has_one
    field :adozioni, as: :has_many, through: :classi
    field :documenti, as: :has_many
    field :documento_righe, as: :has_many, through: :documenti
    field :righe, as: :has_many, through: :documento_righe
  end
end
