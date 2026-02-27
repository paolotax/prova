# == Schema Information
#
# Table name: saggi
#
#  id                :uuid             not null, primary key
#  data_consegna     :date
#  data_prenotazione :date
#  destinatario_type :string
#  note              :text
#  quantita          :integer          default(1), not null
#  stato             :integer          default("prenotato"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  account_id        :uuid             not null
#  destinatario_id   :string
#  documento_riga_id :bigint
#  libro_id          :bigint           not null
#  scuola_id         :uuid             not null
#  user_id           :bigint           not null
#
# Indexes
#
#  idx_saggi_destinatario               (destinatario_type,destinatario_id)
#  index_saggi_on_account_id            (account_id)
#  index_saggi_on_account_id_and_stato  (account_id,stato)
#  index_saggi_on_documento_riga_id     (documento_riga_id)
#  index_saggi_on_libro_id              (libro_id)
#  index_saggi_on_scuola_id             (scuola_id)
#  index_saggi_on_scuola_id_and_stato   (scuola_id,stato)
#  index_saggi_on_user_id               (user_id)
#
class Saggio < ApplicationRecord
  self.table_name = "saggi"

  include AccountScoped

  belongs_to :user
  belongs_to :libro
  belongs_to :scuola
  belongs_to :destinatario, polymorphic: true, optional: true
  belongs_to :documento_riga, optional: true

  enum :stato, { prenotato: 0, consegnato: 1 }

  validates :quantita, numericality: { greater_than: 0 }
  validates :data_prenotazione, presence: true, if: :prenotato?
  validates :data_consegna, presence: true, if: :consegnato?

  before_validation :set_defaults, on: :create

  scope :da_scaricare, -> { consegnato.where(documento_riga_id: nil) }
  scope :scaricati, -> { where.not(documento_riga_id: nil) }
  scope :per_scuola, ->(scuola) { where(scuola: scuola) }

  def scaricato?
    documento_riga_id.present?
  end

  private

  def set_defaults
    self.data_prenotazione ||= Date.current if prenotato?
    self.data_consegna ||= Date.current if consegnato?
    self.user ||= Current.user
  end
end
