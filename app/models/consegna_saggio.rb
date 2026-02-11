# == Schema Information
#
# Table name: consegne_saggio
#
#  id          :uuid             not null, primary key
#  note        :text
#  quantita    :integer          default(1), not null
#  tipo        :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :uuid             not null
#  adozione_id :uuid             not null
#  libro_id    :bigint
#  user_id     :bigint           not null
#
# Indexes
#
#  index_consegne_saggio_on_account_id            (account_id)
#  index_consegne_saggio_on_account_id_and_tipo   (account_id,tipo)
#  index_consegne_saggio_on_adozione_id           (adozione_id)
#  index_consegne_saggio_on_adozione_id_and_tipo  (adozione_id,tipo)
#  index_consegne_saggio_on_libro_id              (libro_id)
#  index_consegne_saggio_on_user_id               (user_id)
#

class ConsegnaSaggio < ApplicationRecord
  self.table_name = "consegne_saggio"

  include AccountScoped

  belongs_to :user
  belongs_to :adozione
  belongs_to :libro, optional: true

  validates :tipo, presence: true, inclusion: { in: %w[saggio kit seguito] }
  validates :quantita, numericality: { greater_than: 0 }

  scope :saggi, -> { where(tipo: "saggio") }
  scope :kit, -> { where(tipo: "kit") }
  scope :seguiti, -> { where(tipo: "seguito") }
end
