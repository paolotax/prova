class FiltersController < ApplicationController
  before_action :authenticate_user!

  def create
    @filter = filter_class.remember(filter_params)
  end

  def destroy
    filter = Current.user.filters.find(params[:id])
    # Keep the params to rebuild an unpersisted filter for the toggle
    @filter = filter.class.from_params(filter.as_params)
    filter.destroy!
  end

  private

  def filter_class
    type = params[:filter_type]&.classify || "Scuola"
    "Filters::#{type}".constantize
  end

  def filter_params
    filter_class.normalize_params(params.permit(*filter_class::Fields::PERMITTED_PARAMS))
  end
end
