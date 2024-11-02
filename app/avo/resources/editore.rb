class Avo::Resources::Editore < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :editore, as: :text
    field :gruppo, as: :text
    field :mandati, as: :has_many
    field :users, as: :has_many, through: :mandati
    field :import_adozioni, as: :has_many
    field :import_scuole, as: :has_many, through: :import_adozioni
  end
end
