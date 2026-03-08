# == Schema Information
#
# Table name: collane
#
#  id         :uuid             not null, primary key
#  nome       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :uuid             not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_collane_on_account_id  (account_id)
#  index_collane_on_user_id     (user_id)
#
class Collana < ApplicationRecord
  include AccountScoped

  belongs_to :user

  has_many :collana_libri, dependent: :destroy
  has_many :libri, through: :collana_libri
  has_many :bolle_visione

  validates :nome, presence: true

  scope :ordered, -> { order(:nome) }
end
