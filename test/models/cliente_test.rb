# == Schema Information
#
# Table name: clienti
#
#  id                      :bigint           not null, primary key
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
#  user_id                 :bigint
#
# Indexes
#
#  index_clienti_on_slug     (slug) UNIQUE
#  index_clienti_on_user_id  (user_id)
#

require "test_helper"

class ClienteTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
