# == Schema Information
#
# Table name: bolla_visione_righe
#
#  id               :uuid             not null, primary key
#  classi_target    :string
#  consegna         :jsonb
#  position         :integer
#  quantita         :integer          default(1), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :uuid             not null
#  bolla_visione_id :uuid             not null
#  libro_id         :bigint           not null
#
# Indexes
#
#  index_bolla_visione_righe_on_account_id        (account_id)
#  index_bolla_visione_righe_on_bolla_visione_id  (bolla_visione_id)
#  index_bolla_visione_righe_on_libro_id          (libro_id)
#
class BollaVisioneRiga < ApplicationRecord
  include AccountScoped

  belongs_to :bolla_visione
  belongs_to :libro

  positioned on: [:bolla_visione_id], column: :position

  validates :quantita, numericality: { greater_than: 0 }

  delegate :titolo, :codice_isbn, to: :libro, prefix: true
end
