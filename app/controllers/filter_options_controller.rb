class FilterOptionsController < ApplicationController
  before_action :authenticate_user!

  def show
    resource = params[:resource]

    unless FilterOptionsCatalog.known?(resource)
      render json: { ok: false, error: "Risorsa non valida. Usa: #{FilterOptionsCatalog.available.join(', ')}" }, status: :unprocessable_entity
      return
    end

    render json: {
      ok: true,
      resource: resource,
      options: FilterOptionsCatalog.for(resource, user: Current.user)
    }
  end
end
