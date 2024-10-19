class AddFascicoliCountToConfezioni < ActiveRecord::Migration[7.1]
  def self.up
    add_column :libri, :fascicoli_count, :integer, null: false, default: 0
  end

  def self.down
    remove_column :libri, :fascicoli_count
  end


  Libro.all.each do |l|
    l.fascicoli_count = l.fascicoli.count
    l.save
  end

end
