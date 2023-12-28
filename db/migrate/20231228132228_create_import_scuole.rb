class CreateImportScuole < ActiveRecord::Migration[7.1]
  def change
    create_table :import_scuole do |t|

      t.string :ANNOSCOLASTICO
      t.string :AREAGEOGRAFICA
      t.string :REGIONE
      t.string :PROVINCIA
      t.string :CODICEISTITUTORIFERIMENTO
      t.string :DENOMINAZIONEISTITUTORIFERIMENTO
      t.string :CODICESCUOLA
      t.string :DENOMINAZIONESCUOLA
      t.string :INDIRIZZOSCUOLA 
      t.string :CAPSCUOLA
      t.string :CODICECOMUNESCUOLA
      t.string :DESCRIZIONECOMUNE
      t.string :DESCRIZIONECARATTERISTICASCUOLA
      t.string :DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA
      t.string :INDICAZIONESEDEDIRETTIVO
      t.string :INDICAZIONESEDEOMNICOMPRENSIVO
      t.string :INDIRIZZOEMAILSCUOLA
      t.string :INDIRIZZOPECSCUOLA
      t.string :SITOWEBSCUOLA
      t.string :SEDESCOLASTICA

      t.timestamps
    end
  end
end
