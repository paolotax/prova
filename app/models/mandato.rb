class Mandato < ApplicationRecord
    belongs_to :editore
    belongs_to :user
end
  