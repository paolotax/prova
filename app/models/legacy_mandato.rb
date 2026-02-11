# == Schema Information
#
# Table name: legacy_mandati
#
#  contratto  :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  editore_id :bigint           not null, primary key
#  user_id    :bigint           not null, primary key
#
# Indexes
#
#  index_legacy_mandati_on_editore_id  (editore_id)
#  index_legacy_mandati_on_user_id     (user_id)
#
class LegacyMandato < ApplicationRecord
  self.table_name = "legacy_mandati"
  self.primary_key = [:user_id, :editore_id]

  belongs_to :editore
  belongs_to :user
end
