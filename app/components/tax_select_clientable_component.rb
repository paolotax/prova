# frozen_string_literal: true

class TaxSelectClientableComponent < ViewComponent::Base

  include FormLabelHelper

  def initialize(form:, type:, id:, field_name_suffix: "documento", object_type: "clientable")
    @form = form
    @type = type
    @id = id
    @field_name_suffix = field_name_suffix
    @object_type = object_type
    @user = Current.user
  end

  private

  attr_accessor :form, :type, :id, :field_name_suffix, :object_type, :user

end
