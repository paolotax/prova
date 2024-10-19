class AddFascicoliCountToConfezioni < ActiveRecord::Migration[7.1]
  def self.up
    add_column :libri, :fascicoli_count, :integer, null: false, default: 0
  end

  def self.down
    remove_column :libri, :fascicoli_count
  end




end
