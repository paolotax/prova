class Avo::Resources::ViewsClasse < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  self.model_class = ::Views::Classe
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :area_geografica, as: :text
    field :regione, as: :text
    field :provincia, as: :text
    field :codice_ministeriale, as: :text
    field :classe, as: :text
    field :sezione, as: :text
    field :combinazione, as: :text
    field :import_adozioni_ids, as: :number
    field :anno, as: :textarea
    field :import_adozioni, as: :has_many
    field :import_scuola, as: :belongs_to
    field :adozioni, as: :has_many
    field :vendita, as: :has_many
    field :omaggio, as: :has_many
    field :adozione, as: :has_many
    field :appunti, as: :has_many
  end
end
