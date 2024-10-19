# == Schema Information
#
# Table name: libri
#
#  id               :bigint           not null, primary key
#  categoria        :string
#  classe           :integer
#  codice_isbn      :string
#  disciplina       :string
#  fascicoli_count  :integer          default(0), not null
#  note             :text
#  numero_fascicoli :integer
#  prezzo_in_cents  :integer
#  titolo           :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  editore_id       :bigint
#  user_id          :bigint           not null
#
# Indexes
#
#  index_libri_on_classe_and_disciplina    (classe,disciplina)
#  index_libri_on_editore_id               (editore_id)
#  index_libri_on_user_id                  (user_id)
#  index_libri_on_user_id_and_categoria    (user_id,categoria)
#  index_libri_on_user_id_and_codice_isbn  (user_id,codice_isbn)
#  index_libri_on_user_id_and_editore_id   (user_id,editore_id)
#  index_libri_on_user_id_and_titolo       (user_id,titolo)
#
# Foreign Keys
#
#  fk_rails_...  (editore_id => editori.id)
#  fk_rails_...  (user_id => users.id)
#
require "test_helper"

class LibroTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
