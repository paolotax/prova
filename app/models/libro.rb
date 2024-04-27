# == Schema Information
#
# Table name: libri
#
#  id              :bigint           not null, primary key
#  categoria       :string
#  classe          :integer
#  codice_isbn     :string
#  disciplina      :string
#  note            :text
#  prezzo_in_cents :integer
#  titolo          :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  editore_id      :bigint
#  user_id         :bigint           not null
#
# Indexes
#
#  index_libri_on_classe_and_disciplina    (classe,disciplina)
#  index_libri_on_editore_id               (editore_id)
#  index_libri_on_user_id                  (user_id)
#  index_libri_on_user_id_and_categoria    (user_id,categoria)
#  index_libri_on_user_id_and_codice_isbn  (user_id,codice_isbn)
#  index_libri_on_user_id_and_editore_id   (user_id,editore_id)
#  index_libri_on_user_id_and_titolo       (user_id,titolo)
#
# Foreign Keys
#
#  fk_rails_...  (editore_id => editori.id)
#  fk_rails_...  (user_id => users.id)
#
class Libro < ApplicationRecord

  monetize :prezzo_in_cents

  belongs_to :user
  belongs_to :editore, optional: true
  
  has_many :adozioni

  validates :titolo, presence: true
  #validates :codice_isbn, presence: true, uniqueness: true
  #validates :prezzo_in_cents, presence: true, numericality: { greater_than: 0 }

  def self.categorie
    order(:categoria).distinct.pluck(:categoria).compact
  end

  def to_combobox_display
    self.titolo
  end

  # ora così poi devo vedere come funziona money-rails
  def prezzo
    prezzo_in_cents.to_f / 100
  end

  def prezzo=(valore)
    self.prezzo_in_cents = (valore.to_f * 100).to_i
  end

end
