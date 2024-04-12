class Libro < ApplicationRecord
  belongs_to :user
  belongs_to :editore
end
