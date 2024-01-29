class Appunto < ApplicationRecord
  belongs_to :import_scuola
  belongs_to :user
  belongs_to :import_adozione
end
