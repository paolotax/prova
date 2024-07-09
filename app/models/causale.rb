# == Schema Information
#
# Table name: causali
#
#  id             :bigint           not null, primary key
#  causale        :string
#  magazzino      :string
#  movimento      :integer
#  tipo_movimento :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
class Causale < ApplicationRecord

  enum tipo_movimento: { carico: 0, scarico: 1}
  enum movimento: { entrata: 0, uscita: 1 }
  
  validates :causale, presence: true
  
  validates :tipo_movimento, presence: true
  validates :movimento, presence: true
  
  validates :magazzino, presence: true

  def to_s
    causale
  end

end
