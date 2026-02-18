# == Schema Information
#
# Table name: cattedra_discipline
#
#  id          :uuid             not null, primary key
#  cattedra    :string           not null
#  disciplina  :string           not null
#  tipo_scuola :string           not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :uuid             not null
#
# Indexes
#
#  idx_cattedra_discipline_unique           (account_id,cattedra,disciplina,tipo_scuola) UNIQUE
#  index_cattedra_discipline_on_account_id  (account_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class CattedraDisciplina < ApplicationRecord
  self.table_name = "cattedra_discipline"

  include AccountScoped

  belongs_to :account

  validates :cattedra, presence: true
  validates :disciplina, presence: true
  validates :tipo_scuola, presence: true
  validates :disciplina, uniqueness: { scope: [:account_id, :cattedra, :tipo_scuola] }

  scope :per_tipo, ->(tipo) { where(tipo_scuola: tipo) }
end
