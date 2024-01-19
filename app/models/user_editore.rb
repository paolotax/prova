class UserEditore < ApplicationRecord
    belongs_to :editore
    belongs_to :user
    
    self.primary_key = [:user_id, :editore_id]
end
  