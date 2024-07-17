# == Schema Information
#
# Table name: documenti
#
#  id               :bigint           not null, primary key
#  clientable_type  :string
#  consegnato_il    :date
#  data_documento   :date
#  iva_cents        :bigint
#  numero_documento :integer
#  pagato_il        :integer
#  spese_cents      :bigint
#  status           :integer
#  tipo_documento   :integer
#  tipo_pagamento   :integer
#  totale_cents     :bigint
#  totale_copie     :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  causale_id       :bigint           not null
#  clientable_id    :bigint
#  user_id          :bigint           not null
#
# Indexes
#
#  index_documenti_on_causale_id                         (causale_id)
#  index_documenti_on_clientable_type_and_clientable_id  (clientable_type,clientable_id)
#  index_documenti_on_user_id                            (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (causale_id => causali.id)
#  fk_rails_...  (user_id => users.id)
#
class Documento < ApplicationRecord
  
  belongs_to :user
  belongs_to :clientable, polymorphic: true
  belongs_to :causale

  has_many :documento_righe, inverse_of: :documento, dependent: :destroy
  has_many :righe, through: :documento_righe

  accepts_nested_attributes_for :documento_righe#,  :reject_if => lambda { |a| (a[:riga_id].nil?)}, :allow_destroy => false

  validates :numero_documento, presence: true
  validates :data_documento, presence: true




  

end
