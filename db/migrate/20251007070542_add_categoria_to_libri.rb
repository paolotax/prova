class AddCategoriaToLibri < ActiveRecord::Migration[8.0]
  def up
    # Aggiunge la colonna categoria_id senza null constraint inizialmente
    add_reference :libri, :categoria, foreign_key: true

    # Popola categoria_id basandosi sul campo categoria esistente
    execute <<-SQL
      UPDATE libri
      SET categoria_id = categorie.id
      FROM categorie
      WHERE libri.categoria = categorie.nome_categoria;
    SQL

    # Assegna la categoria "non classificato" ai libri con categoria blank o nil
    execute <<-SQL
      UPDATE libri
      SET categoria_id = (SELECT id FROM categorie WHERE nome_categoria = 'non classificato')
      WHERE categoria_id IS NULL;
    SQL

    # Ora aggiungi il constraint null: false
    change_column_null :libri, :categoria_id, false
  end

  def down
    remove_reference :libri, :categoria, foreign_key: true
  end
end
