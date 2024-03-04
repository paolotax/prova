class Tappa < ApplicationRecord
  belongs_to :tappable, polymorphic: true
end
