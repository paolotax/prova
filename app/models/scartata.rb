class Scartata < ApplicationRecord
  self.table_name = "scartate"

  include AccountScoped

  belongs_to :scuola
  belongs_to :user, default: -> { Current.user }

  validates :scuola_id, uniqueness: { scope: :user_id }
end
