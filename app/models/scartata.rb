# == Schema Information
#
# Table name: scartate
#
#  id         :uuid             not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :uuid             not null
#  scuola_id  :uuid             not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_scartate_on_account_id             (account_id)
#  index_scartate_on_scuola_id              (scuola_id)
#  index_scartate_on_scuola_id_and_user_id  (scuola_id,user_id) UNIQUE
#  index_scartate_on_user_id                (user_id)
#
class Scartata < ApplicationRecord
  self.table_name = "scartate"

  include AccountScoped

  belongs_to :scuola
  belongs_to :user, default: -> { Current.user }

  validates :scuola_id, uniqueness: { scope: :user_id }
end
