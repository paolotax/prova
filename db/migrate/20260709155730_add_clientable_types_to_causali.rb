class AddClientableTypesToCausali < ActiveRecord::Migration[8.1]
  # Tipi di destinatario per cui la causale è pertinente ([] = tutti).
  # Mappatura ricavata dall'uso reale dei documenti esistenti.
  MAPPATURA = {
    "Documento di trasporto" => [ "Cliente", "Scuola" ],
    "Ordine Cliente" => [ "Cliente" ],
    "Ordine Scuola" => [ "Scuola", "Classe", "Persona" ],
    "Resa Cliente" => [ "Cliente" ],
    "TD01" => [ "Cliente", "Scuola" ],
    "TD04" => [ "Cliente" ],
    "Carico Fornitore" => [ "Cliente" ],
    "DDT Fornitore" => [ "Cliente" ],
    "Resa a Fornitore" => [ "Cliente" ],
    "TD24" => [ "Cliente" ],
    "Campionario" => [ "Scuola", "Cliente" ],
    "Campionario Resa" => [ "Cliente" ],
    "Conto visione" => [ "Scuola" ],
    "Controllo Giacenza" => [],
    "saggi" => [ "Scuola", "Cliente" ],
    "saggi 50" => [ "Cliente" ],
    "Scarico saggi" => [ "Scuola", "Classe", "Persona" ]
  }.freeze

  def up
    add_column :causali, :clientable_types, :json, default: [], null: false

    causali = Class.new(ActiveRecord::Base) { self.table_name = "causali" }
    MAPPATURA.each do |nome, tipi|
      causali.where(causale: nome).update_all(clientable_types: tipi)
    end

    # La colonna scalare è superata dalla mappatura multipla (l'unico valore
    # esistente, Scarico saggi -> Scuola, è coperto dalla MAPPATURA)
    remove_column :causali, :clientable_type
  end

  def down
    add_column :causali, :clientable_type, :string
    remove_column :causali, :clientable_types
  end
end
