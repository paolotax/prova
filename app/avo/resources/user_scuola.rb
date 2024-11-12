class Avo::Resources::UserScuola < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :import_scuola_id, as: :number
    field :user_id, as: :number
    field :import_scuola, as: :belongs_to
    field :user, as: :belongs_to
  end
end
