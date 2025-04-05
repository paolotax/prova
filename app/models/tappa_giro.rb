# == Schema Information
#
# Table name: tappa_giri
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  giro_id    :bigint
#  tappa_id   :bigint
#
# Indexes
#
#  index_tappa_giri_on_giro_id   (giro_id)
#  index_tappa_giri_on_tappa_id  (tappa_id)
#
# Foreign Keys
#
#  fk_rails_...  (giro_id => giri.id)
#  fk_rails_...  (tappa_id => tappe.id)
#
class TappaGiro < ApplicationRecord
  belongs_to :tappa
  belongs_to :giro
end
