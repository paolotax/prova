class UserScuola < ApplicationRecord
  belongs_to :import_scuola
  belongs_to :user
end
