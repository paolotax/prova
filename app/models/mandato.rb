# == Schema Information
#
# Table name: mandati
#
#  id              :uuid             not null, primary key
#  anno_scolastico :string
#  contratto       :text
#  disdetta        :boolean          default(FALSE), not null
#  grado           :string
#  provincia       :string
#  sezioni_count   :integer          default(0)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :uuid             not null
#  editore_id      :bigint           not null
#
# Indexes
#
#  idx_mandati_unique           (account_id,editore_id,provincia,grado,anno_scolastico) UNIQUE
#  index_mandati_on_account_id  (account_id)
#  index_mandati_on_editore_id  (editore_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (editore_id => editori.id)
#
class Mandato < ApplicationRecord
  include AccountScoped

  belongs_to :editore

  validates :editore_id, uniqueness: { scope: [:account_id, :provincia, :grado, :anno_scolastico] }

  scope :attivi, -> { where(disdetta: false) }
  scope :disdetti, -> { where(disdetta: true) }

  after_commit :update_mie_adozioni_async, on: [:create, :destroy]
  after_update_commit :update_mie_adozioni_async, if: :saved_change_to_disdetta?

  # NULL provincia/grado = copre tutti
  def copre_scuola?(scuola)
    (provincia.nil? || provincia == scuola.provincia) &&
      (grado.nil? || grado == scuola.grado)
  end

  private

  def update_mie_adozioni_async
    UpdateMieAdozioniJob.perform_later(account)
  end
end
