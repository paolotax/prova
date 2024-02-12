class Appunto < ApplicationRecord
  belongs_to :import_scuola
  belongs_to :user
  belongs_to :import_adozione, required: false

  has_one_attached :image

end
