# frozen_string_literal: true

class TaxSelectClientableComponent < ViewComponent::Base
  
  
  def initialize(form:, clientable_type:, clientable_id:)
    @form = form
    @clientable_type = clientable_type
    @clientable_id = clientable_id
    @user = Current.user
  end

end
