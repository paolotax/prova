class Avo::Resources::TipoScuola < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :tipo, as: :text
    field :grado, as: :text
    field :import_scuola, as: :belongs_to
  end
end
