class AddNavigatorToPersonalInfos < ActiveRecord::Migration[8.0]
  def change
    add_column :personal_infos, :navigator, :string
  end
end
