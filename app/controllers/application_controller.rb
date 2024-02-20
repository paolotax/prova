class ApplicationController < ActionController::Base

  before_action :congigure_permitted_parameters, if: :devise_controller?
  
  include Pagy::Backend

  protected

    def congigure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :avatar])
      devise_parameter_sanitizer.permit(:account_update, keys: [:name, :avatar])
    end

  private

    def remember_page
        session[:previous_pages] ||= []
        new_page = url_for(params.to_unsafe_h)
        return unless session[:previous_pages].last != new_page
      
        session[:previous_pages] << new_page if request.get?
        session[:previous_pages] = session[:previous_pages].last(2)
    end

end
