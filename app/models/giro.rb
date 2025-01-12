# == Schema Information
#
# Table name: giri
#
#  id          :bigint           not null, primary key
#  descrizione :string
#  finito_il   :datetime
#  iniziato_il :datetime
#  stato       :string
#  titolo      :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_giri_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Giro < ApplicationRecord
  
  belongs_to :user
  
  has_many :tappe, dependent: :nullify

  validates :titolo, presence: true
  
  broadcasts_to ->(giro) { [giro.user, "giri"] }

  def to_combobox_display
    titolo
  end

  def next
    self.class.where("id > ? and user_id = ?", id, user_id).first
  end

  def previous
    self.class.where("id < ? and user_id = ?", id, user_id).last
  end

  def giro_ritiri?
    titolo == "Ritiri"
  end


end
