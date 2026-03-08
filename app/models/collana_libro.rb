# == Schema Information
#
# Table name: collana_libri
#
#  id            :uuid             not null, primary key
#  classi_target :string
#  position      :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :uuid             not null
#  collana_id    :uuid             not null
#  libro_id      :bigint           not null
#
# Indexes
#
#  index_collana_libri_on_account_id               (account_id)
#  index_collana_libri_on_collana_id               (collana_id)
#  index_collana_libri_on_collana_id_and_libro_id  (collana_id,libro_id) UNIQUE
#  index_collana_libri_on_libro_id                 (libro_id)
#
class CollanaLibro < ApplicationRecord
  include AccountScoped

  belongs_to :collana
  belongs_to :libro

  positioned on: [:collana_id], column: :position

  validates :collana_id, uniqueness: { scope: :libro_id }

  scope :ordered, -> { order(:position) }
end
