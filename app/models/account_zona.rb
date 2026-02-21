# == Schema Information
#
# Table name: account_zone
#
#  id              :uuid             not null, primary key
#  anno_scolastico :string
#  grado           :string           not null
#  provincia       :string           not null
#  regione         :string
#  scuole_count    :integer          default(0)
#  stato           :string           default("attiva")
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :uuid             not null
#
# Indexes
#
#  idx_account_zone_unique           (account_id,provincia,grado,anno_scolastico) UNIQUE
#  index_account_zone_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class AccountZona < ApplicationRecord
  self.table_name = "account_zone"

  include AccountScoped
  include AccountZona::GestioneStato

  belongs_to :account

  validates :provincia, presence: true
  validates :grado, presence: true
  validates :provincia, uniqueness: { scope: [:account_id, :grado, :anno_scolastico] }

  after_create_commit :count_scuole_async

  scope :per_anno, ->(anno) { where(anno_scolastico: anno) }
  scope :pronte, -> { where(stato: "pronta") }
  scope :da_rimuovere, -> { where(stato: "da_rimuovere") }

  def grado_label
    TipoScuola::GRADI.to_h.invert[grado] || grado
  end

  def scuole_importate_count
    account.scuole.where(provincia: provincia, grado: grado).count
  end

  def parziale?
    stato == "attiva" && scuole_importate_count < scuole_count
  end

  def import_scuole_per_zona
    tipi = TipoScuola.where(grado: grado).pluck(:tipo)
    ImportScuola.where(PROVINCIA: provincia, DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA: tipi)
  end

  private

  def count_scuole_async
    CountScuolePerZonaJob.perform_later(self)
  end
end
