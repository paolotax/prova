class BackfillDirezioniForAllAccounts < ActiveRecord::Migration[8.1]
  def up
    # Collega ogni scuola (plesso) alla sua direzione tramite codice istituto di riferimento.
    # Una scuola è plesso se import_scuole.CODICEISTITUTORIFERIMENTO è diverso dal suo CODICESCUOLA.
    # La direzione è la scuola nello stesso account con quel codice ministeriale.
    execute <<~SQL
      UPDATE scuole
      SET direzione_id = direzioni.id
      FROM import_scuole,
           scuole AS direzioni
      WHERE scuole.direzione_id IS NULL
        AND scuole.import_scuola_id = import_scuole.id
        AND import_scuole."CODICEISTITUTORIFERIMENTO" IS NOT NULL
        AND import_scuole."CODICEISTITUTORIFERIMENTO" != ''
        AND import_scuole."CODICEISTITUTORIFERIMENTO" != import_scuole."CODICESCUOLA"
        AND direzioni.account_id = scuole.account_id
        AND direzioni.codice_ministeriale = import_scuole."CODICEISTITUTORIFERIMENTO"
    SQL
  end

  def down
    # noop
  end
end
