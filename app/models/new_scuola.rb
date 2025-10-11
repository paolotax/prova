# == Schema Information
#
# Table name: new_scuole
#
#  id                                 :bigint           not null, primary key
#  anno_scolastico                    :string
#  area_geografica                    :string
#  cap                                :string
#  codice_comune                      :string
#  codice_istituto_riferimento        :string
#  codice_scuola                      :string
#  comune                             :string
#  denominazione                      :string
#  denominazione_istituto_riferimento :string
#  descrizione_caratteristica         :string
#  email                              :string
#  indicazione_sede_direttivo         :string
#  indicazione_sede_omnicomprensivo   :string
#  indirizzo                          :string
#  pec                                :string
#  provincia                          :string
#  regione                            :string
#  sede_scolastica                    :string
#  sito_web                           :string
#  tipo_scuola                        :string
#  import_scuola_id                   :bigint
#
# Indexes
#
#  index_new_scuole_on_codice_scuola  (anno_scolastico,codice_scuola) UNIQUE
#

class NewScuola < ApplicationRecord
end
