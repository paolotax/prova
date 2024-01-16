class Editore < ApplicationRecord
    validates :editore, uniqueness: true

    has_many :users, through: :editori_users

    has_many :import_adozioni, foreign_key: "EDITORE", primary_key: "editore"


end
