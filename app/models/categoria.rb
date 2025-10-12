# == Schema Information
#
# Table name: categorie
#
#  id             :bigint           not null, primary key
#  descrizione    :text
#  nome_categoria :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  user_id        :bigint
#
# Indexes
#
#  index_categorie_on_user_id                     (user_id)
#  index_categorie_on_user_id_and_nome_categoria  (user_id,nome_categoria) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
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
