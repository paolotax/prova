class RenameTokenToCodeInMagicLinks < ActiveRecord::Migration[8.0]
  def change
    rename_column :magic_links, :token, :code
  end
end
