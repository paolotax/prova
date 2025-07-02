class ApplicationController < ActionController::Base

  include Pundit::Authorization
  include Pagy::Backend

  # allow_browser versions: :modern

  before_action :set_current_request_identifier
  before_action :congigure_permitted_parameters, if: :devise_controller?
  before_action :set_current_user 

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

    def set_current_request_identifier
      Current.request_id = request.request_id
    end

    def remember_page
        session[:previous_pages] ||= []
        new_page = url_for(params.to_unsafe_h)
        return unless session[:previous_pages].last != new_page
      
        session[:previous_pages] << new_page if request.get?
        session[:previous_pages] = session[:previous_pages].last(2)
    end

end
