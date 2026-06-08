class AddDiscAnnoIndexesToNewTables < ActiveRecord::Migration[8.1]
  disable_ddl_transaction! # richiesto da algorithm: :concurrently

  # Rispecchia su new_adozioni/new_scuole gli indici che import_adozioni/import_scuole
  # già hanno (idx_import_adozioni_disc_anno_tg e idx_on_DESCRIZIONETIPOLOGIA...).
  # Senza questi le Stats che filtrano disciplina+annocorso SENZA predicato
  # tipogradoscuola='EE' (es. stat "letture" #34) facevano seq scan dell'intera
  # new_adozioni (1.3M righe / ~554MB). L'indice parziale EE di
  # 20260605044000 non copre questo caso. TRUNCATE RESTART IDENTITY del reimport
  # conserva gli indici.
  def up
    add_index :new_adozioni, %i[disciplina annocorso tipogradoscuola],
              name: "idx_new_adozioni_disc_anno_tg",
              algorithm: :concurrently,
              if_not_exists: true

    add_index :new_scuole, :tipo_scuola,
              name: "idx_new_scuole_tipo",
              algorithm: :concurrently,
              if_not_exists: true
  end

  def down
    remove_index :new_adozioni, name: "idx_new_adozioni_disc_anno_tg", algorithm: :concurrently, if_exists: true
    remove_index :new_scuole, name: "idx_new_scuole_tipo", algorithm: :concurrently, if_exists: true
  end
end
