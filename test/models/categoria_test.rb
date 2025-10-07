# == Schema Information
#
# Table name: categorie
#
#  id             :integer          not null, primary key
#  nome_categoria :string           not null
#  descrizione    :text
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  user_id        :integer
#
# Indexes
#
#  index_categorie_on_user_id                     (user_id)
#  index_categorie_on_user_id_and_nome_categoria  (user_id,nome_categoria) UNIQUE
#

require "test_helper"

class CategoriaTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
