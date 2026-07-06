# == Schema Information
#
# Table name: miur_scuole
#
#  id                                 :bigint           not null, primary key
#  anno_scolastico                    :string           not null, primary key
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
#  idx_miur_scuole_cod                 (codice_scuola)
#  idx_miur_scuole_tipo                (tipo_scuola)
#  index_miur_scuole_on_codice_scuola  (anno_scolastico,codice_scuola) UNIQUE
#
class Miur::Scuola < ApplicationRecord
  scope :per_anno, ->(anno) { where(anno_scolastico: anno) }

  belongs_to :anagrafe, class_name: "ImportScuola", foreign_key: :import_scuola_id, optional: true
end
