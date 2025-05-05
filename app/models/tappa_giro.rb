# == Schema Information
#
# Table name: tappa_giri
#
#  id         :integer          not null, primary key
#  tappa_id   :integer
#  giro_id    :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_tappa_giri_on_giro_id   (giro_id)
#  index_tappa_giri_on_tappa_id  (tappa_id)
#

class TappaGiro < ApplicationRecord
  belongs_to :tappa
  belongs_to :giro
end
