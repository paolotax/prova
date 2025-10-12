class AddWorkflowToCausali < ActiveRecord::Migration[8.0]
  def up
    add_column :causali, :stato_iniziale, :string
    add_column :causali, :stati_successivi, :json, default: []
    add_column :causali, :priorita, :integer, default: 0
    add_column :causali, :causali_successive, :json, default: []

    add_index :causali, :stato_iniziale
    add_index :causali, :priorita

    # Popola i dati workflow per le causali esistenti
    reversible do |dir|
      dir.up do
        # TD01, TD04, TD24 - Fatture (priorità massima)
        execute <<-SQL
          UPDATE causali
          SET stato_iniziale = 'fattura', priorita = 100
          WHERE causale IN ('TD01', 'TD04', 'TD24');
        SQL

        # DDT - Documenti di trasporto
        execute <<-SQL
          UPDATE causali
          SET stato_iniziale = 'da_registrare',
              stati_successivi = '["fattura"]'::json,
              priorita = 50,
              causali_successive = '["5"]'::json
          WHERE causale = 'Documento di trasporto';
        SQL

        # Ordine Cliente
        execute <<-SQL
          UPDATE causali
          SET stato_iniziale = 'bozza',
              stati_successivi = '["da_consegnare", "da_registrare", "fattura"]'::json,
              priorita = 30,
              causali_successive = '["2", "5"]'::json
          WHERE causale = 'Ordine Cliente';
        SQL

        # Ordine Scuola
        execute <<-SQL
          UPDATE causali
          SET priorita = 50
          WHERE causale = 'Ordine Scuola';
        SQL

        # DDT Fornitore
        execute <<-SQL
          UPDATE causali
          SET priorita = 50
          WHERE causale = 'DDT Fornitore';
        SQL

        # Resa Cliente
        execute <<-SQL
          UPDATE causali
          SET stato_iniziale = 'da_registrare',
              stati_successivi = '["fattura"]'::json,
              priorita = 50,
              causali_successive = '["6"]'::json
          WHERE causale = 'Resa Cliente';
        SQL
      end
    end
  end

  def down
    remove_index :causali, :priorita
    remove_index :causali, :stato_iniziale

    remove_column :causali, :causali_successive
    remove_column :causali, :priorita
    remove_column :causali, :stati_successivi
    remove_column :causali, :stato_iniziale
  end
end
