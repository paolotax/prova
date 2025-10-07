# == Schema Information
#
# Table name: categorie
#
#  id             :integer          not null, primary key
#  nome_categoria :string           not null
#  descrizione    :text
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  user_id        :integer
#
# Indexes
#
#  index_categorie_on_user_id                     (user_id)
#  index_categorie_on_user_id_and_nome_categoria  (user_id,nome_categoria) UNIQUE
#

class Categoria < ApplicationRecord
  belongs_to :user

  has_many :libri, dependent: :restrict_with_error
  has_many :sconti, dependent: :destroy

  validates :nome_categoria, presence: true, uniqueness: { scope: :user_id }
  validates :user_id, presence: true

  def to_s
    nome_categoria
  end

  def to_combobox_display
    nome_categoria
  end
end
