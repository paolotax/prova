# == Schema Information
#
# Table name: scuole
#
#  id                  :uuid             not null, primary key
#  area                :string
#  cap                 :string
#  codice_ministeriale :string
#  comune              :string
#  denominazione       :string
#  email               :string
#  grado               :string
#  indirizzo           :string
#  latitude            :float
#  longitude           :float
#  note                :text
#  pec                 :string
#  posizione           :integer          default(0)
#  priorita            :integer          default(0)
#  provincia           :string
#  regione             :string
#  sigla_provincia     :string(2)
#  stato               :string           default("attiva")
#  telefono            :string
#  tipo_scuola         :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :uuid             not null
#  direzione_id        :uuid
#  import_scuola_id    :bigint
#
# Indexes
#
#  index_scuole_on_account_id                          (account_id)
#  index_scuole_on_account_id_and_codice_ministeriale  (account_id,codice_ministeriale) UNIQUE
#  index_scuole_on_account_id_and_denominazione        (account_id,denominazione)
#  index_scuole_on_account_id_and_direzione_id         (account_id,direzione_id)
#  index_scuole_on_account_id_and_posizione            (account_id,posizione)
#  index_scuole_on_account_provincia_grado             (account_id,provincia,grado)
#  index_scuole_on_import_scuola_id                    (import_scuola_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (import_scuola_id => import_scuole.id)
#
require "test_helper"

class ScuolaTest < ActiveSupport::TestCase
  fixtures :accounts, :scuole

  setup do
    Current.account = accounts(:fizzy)
  end

  teardown do
    Current.account = nil
  end

  test "plessi inherit area from direzione on save" do
    direzione = scuole(:scuola_fizzy)
    plesso = Scuola.create!(
      account: accounts(:fizzy),
      denominazione: "Plesso Test",
      direzione: direzione,
      provincia: "MI",
      grado: "E"
    )

    direzione.update!(area: "Nord")
    plesso.reload

    assert_equal "Nord", plesso.area
  end
end
