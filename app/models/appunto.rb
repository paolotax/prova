class Appunto < ApplicationRecord
  belongs_to :import_scuola
  belongs_to :user
  belongs_to :import_adozione, required: false

  has_one_attached :image
  has_many_attached :files
  has_rich_text :content

end
