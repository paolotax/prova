# == Schema Information
#
# Table name: appunto_righe
#
#  id         :uuid             not null, primary key
#  posizione  :integer          default(0)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  appunto_id :bigint           not null
#  riga_id    :bigint           not null
#
# Indexes
#
#  index_appunto_righe_on_appunto_id                (appunto_id)
#  index_appunto_righe_on_appunto_id_and_posizione  (appunto_id,posizione)
#  index_appunto_righe_on_appunto_id_and_riga_id    (appunto_id,riga_id) UNIQUE
#  index_appunto_righe_on_riga_id                   (riga_id)
#
# Foreign Keys
#
#  fk_rails_...  (appunto_id => appunti.id)
#  fk_rails_...  (riga_id => righe.id)
#
class AppuntoRiga < ApplicationRecord
  acts_as_list scope: :appunto, column: :posizione

  belongs_to :appunto
  belongs_to :riga

  after_save :aggiorna_totali_appunto
  after_destroy :aggiorna_totali_appunto

  delegate :libro, :quantita, :prezzo_cents, :sconto, :importo_cents, to: :riga

  private

  def aggiorna_totali_appunto
    appunto.ricalcola_totali!
  end
end
