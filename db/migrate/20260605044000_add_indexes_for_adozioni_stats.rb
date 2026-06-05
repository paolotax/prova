class AddIndexesForAdozioniStats < ActiveRecord::Migration[8.1]
  disable_ddl_transaction! # richiesto da algorithm: :concurrently

  def up
    # new_adozioni — indice coprente parziale sul sottoinsieme EE (elementari).
    # Serve filtro EE + join su codicescuola + lettura editore/annocorso/disciplina
    # per tutte le query Stats dei sussidiari (144, pagelle ant/mat, gruppi).
    add_index :new_adozioni, :codicescuola,
              name: "idx_new_adoz_ee",
              where: "tipogradoscuola = 'EE'",
              include: %i[editore annocorso disciplina],
              algorithm: :concurrently,
              if_not_exists: true

    # new_scuole — join su codice_scuola + geografia (regione/provincia) index-only.
    add_index :new_scuole, :codice_scuola,
              name: "idx_new_scuole_cod",
              include: %i[regione provincia],
              algorithm: :concurrently,
              if_not_exists: true

    # import_adozioni — colonne maiuscole quotate -> SQL raw.
    execute <<~SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_import_adoz_ee
        ON import_adozioni ("CODICESCUOLA")
        INCLUDE ("EDITORE", "ANNOCORSO", "DISCIPLINA")
        WHERE "TIPOGRADOSCUOLA" = 'EE';
    SQL
  end

  def down
    remove_index :new_adozioni, name: "idx_new_adoz_ee", algorithm: :concurrently, if_exists: true
    remove_index :new_scuole, name: "idx_new_scuole_cod", algorithm: :concurrently, if_exists: true
    execute "DROP INDEX CONCURRENTLY IF EXISTS idx_import_adoz_ee;"
  end
end
