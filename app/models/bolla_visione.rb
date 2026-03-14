# == Schema Information
#
# Table name: bolle_visione
#
#  id           :uuid             not null, primary key
#  data_bolla   :date             not null
#  note         :text
#  numero       :integer          not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :uuid             not null
#  collana_id   :uuid             not null
#  referente_id :uuid
#  scuola_id    :uuid             not null
#  tappa_id     :uuid
#  user_id      :bigint           not null
#
# Indexes
#
#  index_bolle_visione_on_account_id             (account_id)
#  index_bolle_visione_on_account_id_and_numero  (account_id,numero) UNIQUE
#  index_bolle_visione_on_collana_id             (collana_id)
#  index_bolle_visione_on_referente_id           (referente_id)
#  index_bolle_visione_on_scuola_id              (scuola_id)
#  index_bolle_visione_on_tappa_id               (tappa_id)
#  index_bolle_visione_on_user_id                (user_id)
#
class BollaVisione < ApplicationRecord
  include AccountScoped

  belongs_to :user
  belongs_to :collana
  belongs_to :scuola
  belongs_to :tappa, optional: true
  belongs_to :referente, class_name: "Persona", optional: true

  has_many :bolla_visione_righe, dependent: :destroy
  has_many :libri, through: :bolla_visione_righe

  validates :data_bolla, presence: true

  before_create :assegna_numero

  scope :ordered, -> { order(data_bolla: :desc, numero: :desc) }
  scope :per_scuola, ->(scuola) { where(scuola: scuola) }

  def crea_righe_da_collana!(target_filter: [])
    collana.collana_libri.ordered.each do |cl|
      # Se c'è un filtro target, includi solo libri che matchano almeno un tag
      if target_filter.any? && cl.classi_target.present?
        libro_tags = cl.classi_target.split(",").map(&:strip)
        next unless (libro_tags & target_filter).any?
      end

      bolla_visione_righe.create!(
        libro: cl.libro,
        classi_target: cl.classi_target,
        account: account
      )
    end
  end

  private

  def assegna_numero
    max = self.class.where(account_id: account_id).maximum(:numero) || 0
    self.numero = max + 1
  end
end
