# == Schema Information
#
# Table name: new_scuole
#
#  id                                 :bigint           primary key
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

class NewScuola < ApplicationRecord
  # new_scuole e' una vista ponte su miur_scuole (anno corrente):
  # le viste non dichiarano PK ne' ereditano la sequenza dell'id.
  self.primary_key = "id"
  self.sequence_name = "miur_scuole_id_seq"
end
