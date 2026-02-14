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
