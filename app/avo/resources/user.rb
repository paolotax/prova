class Avo::Resources::User < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: params[:q], m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :name, as: :text
    field :email, as: :text
    field :partita_iva, as: :text
    field :navigator, as: :text
    field :confirmation_token, as: :text
    field :confirmed_at, as: :date_time
    field :confirmation_sent_at, as: :date_time
    field :unconfirmed_email, as: :text
    field :role, as: :select, enum: ::User.roles
    field :avatar, as: :file
    field :profile, as: :has_one
    field :user_scuole, as: :has_many
    field :import_scuole, as: :has_many, through: :user_scuole
    field :import_adozioni, as: :has_many, through: :import_scuole
    field :classi, as: :has_many, through: :import_scuole
    field :mie_adozioni, as: :has_many, through: :import_scuole
    field :mandati, as: :has_many
    field :editori, as: :has_many, through: :mandati
    field :adozioni, as: :has_many
    field :documenti, as: :has_many
    field :clienti, as: :has_many
    field :righe, as: :has_many, through: :documenti
    field :appunti, as: :has_many
    field :giri, as: :has_many
    field :tappe, as: :has_many
    field :libri, as: :has_many
    field :card, as: :trix
  end
end
