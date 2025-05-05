# == Schema Information
#
# Table name: clienti
#
#  id                      :integer          not null, primary key
#  codice_cliente          :string
#  tipo_cliente            :string
#  indirizzo_telematico    :string
#  email                   :string
#  pec                     :string
#  telefono                :string
#  id_paese                :string
#  partita_iva             :string
#  codice_fiscale          :string
#  denominazione           :string
#  nome                    :string
#  cognome                 :string
#  codice_eori             :string
#  nazione                 :string
#  cap                     :string
#  provincia               :string
#  comune                  :string
#  indirizzo               :string
#  numero_civico           :string
#  beneficiario            :string
#  condizioni_di_pagamento :string
#  metodo_di_pagamento     :string
#  banca                   :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  user_id                 :integer
#  slug                    :string
#  latitude                :float
#  longitude               :float
#  geocoded                :boolean
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
