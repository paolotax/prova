class Avo::Resources::Causale < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :causale, as: :text
    field :magazzino, as: :text
    field :tipo_movimento, as: :select, enum: ::Causale.tipo_movimentos
    field :movimento, as: :select, enum: ::Causale.movimentos
  end
end
