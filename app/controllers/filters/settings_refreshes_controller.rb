class Filters::SettingsRefreshesController < ApplicationController
  before_action :authenticate_user!

  def create
    filter_type = params[:filter_type] || "scuola"
    filter_class = "Filters::#{filter_type.classify}".constantize
    @filter = filter_class.from_params(filter_params(filter_class))
  end

  private

  def filter_params(filter_class)
    params.permit(*filter_class::Fields::PERMITTED_PARAMS)
  end
end
