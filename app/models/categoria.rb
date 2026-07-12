# == Schema Information
#
# Table name: categorie
#
#  id             :bigint           not null, primary key
#  descrizione    :text
#  nome_categoria :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :uuid             not null
#
# Indexes
#
#  index_categorie_on_account_id                     (account_id)
#  index_categorie_on_account_id_and_nome_categoria  (account_id, lower(TRIM(BOTH FROM nome_categoria))) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#

class Categoria < ApplicationRecord
  include AccountScoped

  DEFAULT_NAME = "non classificato"

  has_many :libri, dependent: :restrict_with_error
  has_many :sconti, dependent: :destroy

  validates :nome_categoria, presence: true, uniqueness: { scope: :account_id, case_sensitive: false }

  before_validation :normalize_nome

  # Trova o crea una categoria normalizzata per l'account.
  # Se nome è blank, ritorna la categoria default "non classificato".
  def self.resolve(nome, account:)
    nome = nome.to_s.downcase.strip
    nome = DEFAULT_NAME if nome.blank?

    cat = where(account_id: account.id).where("LOWER(TRIM(nome_categoria)) = ?", nome).first
    cat || create!(nome_categoria: nome, account_id: account.id)
  end

  def to_s
    nome_categoria
  end

  def to_combobox_display
    nome_categoria
  end

  private

  def normalize_nome
    self.nome_categoria = nome_categoria.to_s.downcase.strip if nome_categoria.present?
  end
end
