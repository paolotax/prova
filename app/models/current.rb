class Current < ActiveSupport::CurrentAttributes
  attribute :user
  attribute :request_id
  
  def user=(user)
    super
  end
end