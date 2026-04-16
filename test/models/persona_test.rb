# == Schema Information
#
# Table name: persone
#
#  id         :uuid             not null, primary key
#  cellulare  :string
#  cognome    :string
#  email      :string
#  nome       :string
#  note       :text
#  posizione  :integer
#  ruolo      :string
#  telefono   :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :uuid             not null
#  scuola_id  :uuid
#
# Indexes
#
#  index_persone_on_account_id                       (account_id)
#  index_persone_on_account_id_and_cognome_and_nome  (account_id,cognome,nome)
#  index_persone_on_scuola_id                        (scuola_id)
#  index_persone_on_scuola_id_and_ruolo              (scuola_id,ruolo)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (scuola_id => scuole.id)
#
require "test_helper"

class PersonaTest < ActiveSupport::TestCase
  fixtures :persone, :scuole, :accounts

  test "tappa_target returns scuola when present" do
    persona = persone(:persona_fizzy)
    assert_equal persona.scuola, persona.tappa_target
  end

  test "tappa_target is nil without scuola" do
    persona = persone(:persona_fizzy_no_scuola)
    assert_nil persona.tappa_target
  end
end
