class CreateNewScuole < ActiveRecord::Migration[7.1]
  def change
    create_table :new_scuole do |t|
      t.string :anno_scolastico
      t.string :area_geografica
      t.string :regione
      t.string :provincia
      t.string :codice_istituto_riferimento
      t.string :denominazione_istituto_riferimento
      t.string :codice_scuola
      t.string :denominazione
      t.string :indirizzo
      t.string :cap
      t.string :codice_comune
      t.string :comune
      t.string :descrizione_caratteristica
      t.string :tipo_scuola
      t.string :indicazione_sede_direttivo
      t.string :indicazione_sede_omnicomprensivo
      t.string :email
      t.string :pec
      t.string :sito_web
      t.string :sede_scolastica
      t.bigint :import_scuola_id
    end

    add_index :new_scuole, [:anno_scolastico, :codice_scuola], unique: true, name: 'index_new_scuole_on_codice_scuola'
  end
end


#  ANNOSCOLASTICO                            :string
#  AREAGEOGRAFICA                            :string
#  CAPSCUOLA                                 :string
#  CODICECOMUNESCUOLA                        :string
#  CODICEISTITUTORIFERIMENTO                 :string
#  CODICESCUOLA                              :string
#  DENOMINAZIONEISTITUTORIFERIMENTO          :string
#  DENOMINAZIONESCUOLA                       :string
#  DESCRIZIONECARATTERISTICASCUOLA           :string
#  DESCRIZIONECOMUNE                         :string
#  DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA :string
#  INDICAZIONESEDEDIRETTIVO                  :string
#  INDICAZIONESEDEOMNICOMPRENSIVO            :string
#  INDIRIZZOEMAILSCUOLA                      :string
#  INDIRIZZOPECSCUOLA                        :string
#  INDIRIZZOSCUOLA                           :string
#  PROVINCIA                                 :string
#  REGIONE                                   :string
#  SEDESCOLASTICA                            :string
#  SITOWEBSCUOLA                             :string