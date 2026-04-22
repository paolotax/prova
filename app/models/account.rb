# == Schema Information
#
# Table name: accounts
#
#  id                                :uuid             not null, primary key
#  adozioni_aggiornamento_started_at :datetime
#  adozioni_aggiornate_at            :datetime
#  name                              :string           not null
#  slug                              :string
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#
# Indexes
#
#  index_accounts_on_slug  (slug) UNIQUE
#
class Account < ApplicationRecord
  include Account::GestioneMandati
  include Account::Distribuzione

  has_many :memberships, class_name: "Accounts::Membership", dependent: :destroy
  has_many :users, through: :memberships

  # Zone e mandati (account-level)
  has_many :zone, class_name: "Accounts::Zona", dependent: :destroy
  has_many :mandati, class_name: "Accounts::Mandato", dependent: :destroy

  # Account-scoped resources
  has_one :azienda, dependent: :destroy
  has_many :appunti, dependent: :destroy
  has_many :documenti, dependent: :destroy
  has_many :clienti, dependent: :destroy
  has_many :libri, dependent: :destroy
  has_many :scuole, dependent: :destroy
  has_many :classi, dependent: :destroy
  has_many :adozioni, dependent: :destroy
  has_many :persone, dependent: :destroy
  has_many :import_records, dependent: :destroy
  has_many :collane, dependent: :destroy
  has_many :collana_libri, dependent: :destroy
  has_many :bolle_visione, dependent: :destroy
  has_many :bolla_visione_righe, dependent: :destroy

  # Triage system
  has_many :columns, dependent: :destroy
  has_many :entries, dependent: :destroy
  has_many :events, dependent: :destroy

  validates :name, presence: true

  def member?(user)
    users.exists?(user.id)
  end

  def add_member(user, role: :member)
    memberships.find_or_create_by!(user: user) do |membership|
      membership.role = role
    end
  end

  def remove_member(user)
    memberships.find_by(user: user)&.destroy
  end

  def owner
    memberships.find_by(role: :owner)&.user
  end

  def add_zone!(regione:, provincia: nil, grado: nil)
    province = if provincia.present?
                 [provincia]
               else
                 Zona.where(regione: regione).distinct.pluck(:provincia).sort
               end
    gradi = if grado.present?
              [grado]
            else
              TipoScuola::GRADI.reject { |g| g[1].in?(%w[I altro]) }.map(&:last)
            end

    province.each do |prov|
      gradi.each do |gr|
        zona = zone.find_or_create_by!(provincia: prov, grado: gr) do |z|
          z.regione = regione
          z.anno_scolastico = "2025/2026"
          z.stato = "conteggio"
        end

        # Zona già esistente → rilancia conteggio per reimportare scuole mancanti
        if zona.stato.in?(%w[attiva importazione pulizia])
          zona.update!(stato: "conteggio")
          CountScuolePerZonaJob.perform_later(zona)
        end
      end
    end
  end

  def aggiornamento_adozioni_in_corso?
    adozioni_aggiornamento_started_at.present? &&
      (adozioni_aggiornate_at.nil? || adozioni_aggiornate_at < adozioni_aggiornamento_started_at)
  end

  def adozioni_stale?
    return false if aggiornamento_adozioni_in_corso?
    return true  if adozioni_aggiornate_at.nil?

    ultima_modifica = [zone.maximum(:updated_at), mandati.maximum(:updated_at)].compact.max
    ultima_modifica.present? && ultima_modifica > adozioni_aggiornate_at
  end

  def zone_tutte_attive?
    zone.where.not(stato: "attiva").none?
  end
end
