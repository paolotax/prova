class Avo::Resources::Tappa < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :titolo, as: :text
    field :descrizione, as: :text
    field :ordine, as: :number
    field :data_tappa, as: :date_time
    field :entro_il, as: :date_time
    field :tappable_type, as: :text
    field :tappable_id, as: :number
    field :giro_id, as: :number
    field :user_id, as: :number
    field :user, as: :belongs_to
    field :giro, as: :belongs_to
    field :tappable, as: :belongs_to
    field :import_scuola, as: :belongs_to
  end
end
