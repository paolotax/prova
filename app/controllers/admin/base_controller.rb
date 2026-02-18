class Admin::BaseController < ApplicationController
  before_action :require_superadmin!

  layout "admin"

  private

    def require_superadmin!
      unless current_user&.email == "paolo.tassinari@hey.com"
        redirect_to root_path, alert: "Accesso non autorizzato"
      end
    end
end
