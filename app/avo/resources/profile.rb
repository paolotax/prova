class Avo::Resources::Profile < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :user_id, as: :number
    field :nome, as: :text
    field :cognome, as: :text
    field :ragione_sociale, as: :text
    field :indirizzo, as: :text
    field :cap, as: :text
    field :citta, as: :text
    field :cellulare, as: :text
    field :email, as: :text
    field :iban, as: :text
    field :nome_banca, as: :text
    field :user, as: :belongs_to
  end
end
