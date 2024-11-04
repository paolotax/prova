class Avo::Resources::Giro < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :user_id, as: :number
    field :iniziato_il, as: :date_time
    field :finito_il, as: :date_time
    field :titolo, as: :text
    field :descrizione, as: :text
    field :stato, as: :text
    field :user, as: :belongs_to
    field :tappe, as: :has_many
  end
end
