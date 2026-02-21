# == Schema Information
#
# Table name: accounts
#
#  id         :uuid             not null, primary key
#  name       :string           not null
#  slug       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_accounts_on_slug  (slug) UNIQUE
#
class Account < ApplicationRecord
  include Account::GestioneMandati
  include Account::Distribuzione

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  # Zone e mandati (account-level)
  has_many :account_zone, class_name: "AccountZona", dependent: :destroy
  has_many :mandati, dependent: :destroy

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
        zona = account_zone.find_or_create_by!(provincia: prov, grado: gr) do |z|
          z.regione = regione
          z.anno_scolastico = "2025/2026"
          z.stato = "conteggio"
        end

        # Zona già esistente e attiva → rilancia conteggio per reimportare scuole mancanti
        if zona.stato == "attiva"
          zona.update!(stato: "conteggio")
          CountScuolePerZonaJob.perform_later(zona)
        end
      end
    end
  end
end
