# == Schema Information
#
# Table name: clienti
#
#  id                      :uuid             not null, primary key
#  banca                   :string
#  beneficiario            :string
#  cap                     :string
#  codice_cliente          :string
#  codice_eori             :string
#  codice_fiscale          :string
#  cognome                 :string
#  comune                  :string
#  condizioni_di_pagamento :string
#  denominazione           :string
#  email                   :string
#  fornitore               :boolean          default(FALSE), not null
#  geocoded                :boolean
#  id_paese                :string
#  indirizzo               :string
#  indirizzo_telematico    :string
#  latitude                :float
#  longitude               :float
#  metodo_di_pagamento     :string
#  nazione                 :string
#  nome                    :string
#  numero_civico           :string
#  partita_iva             :string
#  pec                     :string
#  provincia               :string
#  slug                    :string
#  telefono                :string
#  tipo_cliente            :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  account_id              :uuid             not null
#  user_id                 :bigint
#
# Indexes
#
#  index_clienti_on_account_id                 (account_id)
#  index_clienti_on_account_id_and_created_at  (account_id,created_at)
#  index_clienti_on_slug                       (slug) UNIQUE
#  index_clienti_on_user_id                    (user_id)
#
require "test_helper"

class ClienteTest < ActiveSupport::TestCase
  fixtures :accounts, :users, :memberships, :clienti

  setup do
    Current.account = accounts(:fizzy)
    Current.user = users(:one)
  end

  teardown do
    Current.reset
  end

  test "fornitori scope returns only clienti flagged as fornitore" do
    assert_includes Cliente.fornitori, clienti(:cliente_fornitore_fizzy)
    assert_not_includes Cliente.fornitori, clienti(:cliente_fizzy)
  end
end
