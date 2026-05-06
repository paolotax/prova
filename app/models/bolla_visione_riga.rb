# == Schema Information
#
# Table name: bolla_visione_righe
#
#  id                :uuid             not null, primary key
#  classi_target     :string
#  consegna          :jsonb
#  esito             :integer
#  position          :integer
#  processato_at     :datetime
#  quantita          :integer          default(1), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :uuid             not null
#  bolla_visione_id  :uuid             not null
#  documento_riga_id :bigint
#  libro_id          :bigint           not null
#
# Indexes
#
#  index_bolla_visione_righe_on_account_id                  (account_id)
#  index_bolla_visione_righe_on_bolla_visione_id            (bolla_visione_id)
#  index_bolla_visione_righe_on_bolla_visione_id_and_esito  (bolla_visione_id,esito)
#  index_bolla_visione_righe_on_documento_riga_id           (documento_riga_id)
#  index_bolla_visione_righe_on_libro_id                    (libro_id)
#  index_bolla_visione_righe_on_processato_at               (processato_at)
#
# Foreign Keys
#
#  fk_rails_...  (documento_riga_id => documento_righe.id)
#
class BollaVisioneRiga < ApplicationRecord
  include AccountScoped

  belongs_to :bolla_visione
  belongs_to :libro

  positioned on: [:bolla_visione_id], column: :position

  validates :quantita, numericality: { greater_than: 0 }

  delegate :titolo, :codice_isbn, to: :libro, prefix: true
end
