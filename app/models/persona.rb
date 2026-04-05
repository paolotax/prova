# == Schema Information
#
# Table name: persone
#
#  id         :uuid             not null, primary key
#  cellulare  :string
#  cognome    :string
#  email      :string
#  nome       :string
#  note       :text
#  posizione  :integer
#  ruolo      :string
#  telefono   :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :uuid             not null
#  scuola_id  :uuid
#
# Indexes
#
#  index_persone_on_account_id                       (account_id)
#  index_persone_on_account_id_and_cognome_and_nome  (account_id,cognome,nome)
#  index_persone_on_scuola_id                        (scuola_id)
#  index_persone_on_scuola_id_and_ruolo              (scuola_id,ruolo)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (scuola_id => scuole.id)
#
class Persona < ApplicationRecord
  include AccountScoped
  include Appuntabile
  include Persona::Avatar

  belongs_to :scuola, optional: true

  has_many :persona_classi, dependent: :destroy
  has_many :classi, through: :persona_classi
  has_many :saggi, class_name: "Saggio", as: :destinatario, dependent: :nullify

  enum :ruolo, { docente: "docente", dirigente: "dirigente", segretario: "segretario", referente: "referente", altro: "altro" }

  normalizes :nome, :cognome, with: ->(val) { val.strip.gsub(/\s+/, " ").downcase.gsub(/(?<=\A|[ '.])\w/, &:upcase) }

  validate :cognome_o_nome_presente

  scope :per_ruolo, ->(ruolo) { where(ruolo: ruolo) }
  scope :per_scuola, ->(scuola) { where(scuola: scuola) }
  scope :ilike_search, ->(query) { where("cognome ILIKE :q OR nome ILIKE :q", q: "%#{query}%") }

  def nome_completo
    "#{nome} #{cognome}".strip
  end

  alias_method :denominazione, :nome_completo

  def to_s
    nome_completo
  end

  def to_combobox_display
    if scuola.present?
      "#{nome_completo} - #{scuola.denominazione}"
    else
      nome_completo
    end
  end

  private

  def cognome_o_nome_presente
    if cognome.blank? && nome.blank?
      errors.add(:base, "Cognome o nome deve essere presente")
    end
  end
end
