class BackfillMiaOnAdozioni < ActiveRecord::Migration[8.0]
  def up
    # Aggiorna adozioni.mia = true dove l'editore dell'adozione
    # corrisponde a un editore con mandato per un utente dello stesso account
    execute <<~SQL
      UPDATE adozioni
      SET mia = true
      WHERE EXISTS (
        SELECT 1
        FROM memberships m
        JOIN mandati ma ON ma.user_id = m.user_id
        JOIN editori e ON e.id = ma.editore_id
        WHERE m.account_id = adozioni.account_id
          AND e.editore = adozioni.editore
      )
    SQL
  end

  def down
    execute "UPDATE adozioni SET mia = false"
  end
end
