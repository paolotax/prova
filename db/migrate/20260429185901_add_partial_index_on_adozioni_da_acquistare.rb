class AddPartialIndexOnAdozioniDaAcquistare < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :adozioni,
              [:account_id, :classe_id],
              where: "da_acquistare = true",
              name: "index_adozioni_on_account_classe_da_acquistare",
              algorithm: :concurrently,
              if_not_exists: true
  end
end
