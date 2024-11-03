class ApplicationController < ActionController::Base

  include Pundit

  before_action :congigure_permitted_parameters, if: :devise_controller?
  
  before_action :set_current_user 

  include Pagy::Backend

  protected

    def congigure_permitted_parameters

      added_attrs = [:name, :email, :password, :password_confirmation, :remember_me, :avatar]
      devise_parameter_sanitizer.permit(:sign_in, keys: added_attrs)

      devise_parameter_sanitizer.permit(:sign_up, keys: added_attrs)
      devise_parameter_sanitizer.permit(:account_update, keys: added_attrs)
    end

  private

    def set_current_user
      Current.user = current_user if current_user
    end

    def remember_page
        session[:previous_pages] ||= []
        new_page = url_for(params.to_unsafe_h)
        return unless session[:previous_pages].last != new_page
      
        session[:previous_pages] << new_page if request.get?
        session[:previous_pages] = session[:previous_pages].last(2)
    end

end
