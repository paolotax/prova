class Avo::Resources::Appunto < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :import_scuola_id, as: :number
    field :user_id, as: :number
    field :import_adozione_id, as: :number
    field :nome, as: :text
    field :body, as: :textarea
    field :email, as: :text
    field :telefono, as: :text
    field :stato, as: :text
    field :completed_at, as: :date_time
    field :team, as: :text
    field :classe_id, as: :number
    field :image, as: :file
    field :attachments, as: :files
    field :import_scuola, as: :belongs_to
    field :user, as: :belongs_to
    field :import_adozione, as: :belongs_to
    field :classe, as: :belongs_to
    field :tappe, as: :has_many
    field :content, as: :trix
  end
end
