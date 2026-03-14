# == Schema Information
#
# Table name: disponibilita
#
#  id               :uuid             not null, primary key
#  data             :date
#  giorno_settimana :integer
#  ora_fine         :time
#  ora_inizio       :time
#  ricorrente       :boolean          default(FALSE)
#  tipo             :string           not null
#  titolo           :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :uuid             not null
#  scuola_id        :uuid             not null
#  user_id          :bigint
#
# Indexes
#
#  idx_disponibilita_scuola_tipo_giorno       (scuola_id,tipo,giorno_settimana)
#  index_disponibilita_on_account_id          (account_id)
#  index_disponibilita_on_scuola_id           (scuola_id)
#  index_disponibilita_on_scuola_id_and_tipo  (scuola_id,tipo)
#  index_disponibilita_on_user_id             (user_id)
#
class Disponibilita < ApplicationRecord
  include AccountScoped

  belongs_to :scuola
  belongs_to :user, optional: true

  TIPI = %w[orario chiusura patrono seggio riunione nota].freeze
  GIORNI = { 1 => "Lunedì", 2 => "Martedì", 3 => "Mercoledì",
             4 => "Giovedì", 5 => "Venerdì", 6 => "Sabato", 0 => "Domenica" }.freeze

  validates :tipo, presence: true, inclusion: { in: TIPI }
  validates :giorno_settimana, presence: true, if: -> { tipo.in?(%w[orario riunione]) }
  validates :data, presence: true, if: -> { tipo.in?(%w[chiusura patrono]) }

  before_validation :set_ricorrente_for_patrono

  scope :orari, -> { where(tipo: "orario").order(:giorno_settimana, :ora_inizio) }
  scope :chiusure, -> { where(tipo: "chiusura").order(:data) }
  scope :chiusure_future, -> { chiusure.where("data >= ?", Date.today) }
  scope :patroni, -> { where(tipo: "patrono") }
  scope :seggi, -> { where(tipo: "seggio") }
  scope :riunioni, -> { where(tipo: "riunione").order(:giorno_settimana, :ora_inizio) }
  scope :note_utente, -> { where(tipo: "nota") }
  scope :della_scuola, -> { where(user_id: nil) }
  scope :dell_utente, ->(user) { where(user_id: user.id) }

  def orario_label
    return unless ora_inizio && ora_fine
    "#{ora_inizio.strftime('%H:%M')}-#{ora_fine.strftime('%H:%M')}"
  end

  def giorno_label
    GIORNI[giorno_settimana]
  end

  private

  def set_ricorrente_for_patrono
    self.ricorrente = true if tipo == "patrono"
  end
end
