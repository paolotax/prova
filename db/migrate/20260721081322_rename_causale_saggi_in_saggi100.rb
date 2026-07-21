class RenameCausaleSaggiInSaggi100 < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE causali SET causale = 'saggi 100' WHERE causale = 'saggi'"
  end

  def down
    execute "UPDATE causali SET causale = 'saggi' WHERE causale = 'saggi 100'"
  end
end
