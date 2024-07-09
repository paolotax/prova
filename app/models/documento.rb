class Documento < ApplicationRecord
  belongs_to :user
  belongs_to :cliente
  belongs_to :causale
end
