class AddAdozioniAggiornamentoToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :adozioni_aggiornamento_started_at, :datetime
    add_column :accounts, :adozioni_aggiornate_at, :datetime
  end
end
