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
  belongs_to :documento_riga, optional: true

  positioned on: [:bolla_visione_id], column: :position

  enum :esito, {
    in_saggio: 0,
    venduto_fattura: 1,
    venduto_corrispettivi: 2,
    mancante: 3,
    rientrato: 4
  }

  scope :aperte, -> { where(processato_at: nil) }
  scope :chiuse, -> { where.not(processato_at: nil) }

  validates :quantita, numericality: { greater_than: 0 }

  delegate :titolo, :codice_isbn, to: :libro, prefix: true

  # Quando questa riga e' una confezione e l'utente segnala alcuni fascicoli mancanti:
  # - crea N nuove righe-fascicolo con esito :mancante e processato_at corrente
  # - chiude la riga-confezione originale con l'esito scelto per i fascicoli rimanenti
  # Ritorna le nuove righe-fascicolo (per appenderle al documento Mancante).
  def splitta_in_fascicoli!(fascicoli, esito_confezione:)
    raise ArgumentError, "fascicoli vuoti" if fascicoli.blank?

    transaction do
      nuove = fascicoli.map do |fascicolo|
        bolla_visione.bolla_visione_righe.create!(
          libro: fascicolo,
          quantita: 1,
          account: account,
          esito: :mancante,
          processato_at: Time.current
        )
      end
      update!(esito: esito_confezione, processato_at: Time.current)
      nuove
    end
  end

  def splitta!
    return self if quantita <= 1

    transaction do
      quantita.times do
        bolla_visione.bolla_visione_righe.create!(
          libro: libro,
          classi_target: classi_target,
          quantita: 1,
          account: account
        )
      end
      destroy!
    end
  end
end
