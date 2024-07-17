# == Schema Information
#
# Table name: righe
#
#  id                     :bigint           not null, primary key
#  iva_cents              :integer          default(0)
#  prezzo_cents           :integer          default(0)
#  prezzo_copertina_cents :integer          default(0)
#  quantita               :integer          default(1)
#  sconto                 :decimal(5, 2)    default(0.0)
#  status                 :integer
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  libro_id               :bigint           not null
#
# Indexes
#
#  index_righe_on_libro_id  (libro_id)
#
# Foreign Keys
#
#  fk_rails_...  (libro_id => libri.id)
#
require "test_helper"

class RigaTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
