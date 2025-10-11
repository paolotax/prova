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

require "test_helper"

class CategoriaTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
