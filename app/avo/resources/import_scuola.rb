class Avo::Resources::ImportScuola < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  self.search = {
    query: -> { query.ransack(
      CODICESCUOLA_cont: params[:q], 
      PROVINCIA_cont: params[:q],
      DESCRIZIONECOMUNE_cont: params[:q],
      DENOMINAZIONESCUOLA_cont: params[:q],
      m: "or").result(distinct: false) },
    item: -> do
      { title: "#{record.DENOMINAZIONESCUOLA} --- #{record.DESCRIZIONECOMUNE}" }
    end
  }
  
  self.includes = [:direzione]

  def fields
    field :id, as: :id
    field :ANNOSCOLASTICO, as: :text
    field :AREAGEOGRAFICA, as: :text
    field :REGIONE, as: :text
    field :PROVINCIA, as: :text
    field :CODICEISTITUTORIFERIMENTO, as: :text
    field :DENOMINAZIONEISTITUTORIFERIMENTO, as: :text
    field :CODICESCUOLA, as: :text
    field :DENOMINAZIONESCUOLA, as: :text
    field :INDIRIZZOSCUOLA, as: :text
    field :CAPSCUOLA, as: :text
    field :CODICECOMUNESCUOLA, as: :text
    field :DESCRIZIONECOMUNE, as: :text
    field :DESCRIZIONECARATTERISTICASCUOLA, as: :text
    field :DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA, as: :text
    field :INDICAZIONESEDEDIRETTIVO, as: :text
    field :INDICAZIONESEDEOMNICOMPRENSIVO, as: :text
    field :INDIRIZZOEMAILSCUOLA, as: :text
    field :INDIRIZZOPECSCUOLA, as: :text
    field :SITOWEBSCUOLA, as: :text
    field :SEDESCOLASTICA, as: :text
    field :slug, as: :text
    field :import_adozioni, as: :has_many
    field :user_scuole, as: :has_many
  end

  self.find_record_method = -> {
    if id.is_a?(Array)
      query.where(slug: id)
    else
      # We have to add .friendly to the query
      query.friendly.find id
    end
  }
  
end
