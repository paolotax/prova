class ApplicationController < ActionController::Base

  include Pundit::Authorization
  include Pagy::Backend
  include PasswordlessAuthentication

  # allow_browser versions: :modern

  before_action :set_current_request_identifier
  before_action :authenticate_user!

  private

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
